local M = {}
local codec = require("bunvim.rpc.codec")
M.bytes = codec.bytes
M.bytes_value = codec.bytes_value
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
local configuration = require("bunvim.host.configuration")
local config = configuration.create()

local state = {
  status = "idle",
  plugins = {},
  next_generation = 0,
  start_callbacks = {},
  stop_callbacks = {},
  logs = {},
}
local vim_api = require("bunvim.vim").create()
M._vim = vim_api

local close_timer = function(timer)
  if not timer or timer:is_closing() then return end
  timer:stop()
  timer:close()
end

local report_error = function(message)
  vim.schedule(function()
    vim.notify("Bunvim: " .. message, vim.log.levels.ERROR)
  end)
end

local run_callback = function(callback, err, result)
  if not callback then
    if err then report_error(err) end
    return
  end

  vim.schedule(function()
    local ok, callback_error = pcall(callback, err, result)
    if not ok then report_error(tostring(callback_error)) end
  end)
end

local requests = require("bunvim.host.requests").create(state, config, run_callback)

local invoke = function(name, handler, input, bufnr, generation)
  if state.status ~= "running" then return end
  local plugin = state.plugins[name]
  if not plugin or plugin.status == "unloading" or plugin.generation ~= generation then return end

  requests.submit("bunvim:call", { name, handler, input, requests.get_origin(bufnr), generation })
end

local registrations = require("bunvim.host.registrations").create(invoke, requests.invoke_sync)

local finish_start = function(err)
  state.is_starting = false
  local callbacks = state.start_callbacks
  state.start_callbacks = {}
  for _, callback in ipairs(callbacks) do
    run_callback(callback, err)
  end

  if err and #callbacks == 0 then report_error(err) end
  if not err and state.status == "running" then
    vim.api.nvim_exec_autocmds("User", { pattern = "BunvimReady", modeline = false })
  end
end

local load_plugin = function(name, plugin, callback)
  local channel = state.channel
  plugin.status = "loading"
  state.next_generation = state.next_generation + 1
  plugin.generation = state.next_generation
  requests.submit(
    "bunvim:load",
    { name, plugin.path, plugin.options == nil and vim.NIL or plugin.options, plugin.generation },
    {
      lifecycle_timeout_ms = config.setup_timeout_ms,
      on_complete = function(err, result)
        if
          state.channel == channel
          and state.status == "running"
          and state.plugins[name] == plugin
          and plugin.status == "loading"
        then
          plugin.status = err and "failed" or "loaded"
          plugin.error = err
          plugin.functions = result and result.functions or nil
        end

        if callback then callback(err, result) end
      end,
    }
  )
end

M._ready = function(channel)
  if channel ~= state.channel or state.status ~= "starting" then return end
  close_timer(state.start_timer)
  state.start_timer = nil
  state.status = "running"
  local names = vim.tbl_keys(state.plugins)
  table.sort(names)
  local remaining = #names
  local errors = {}
  for _, name in ipairs(names) do
    load_plugin(name, state.plugins[name], function(err)
      if err then table.insert(errors, name .. ": " .. err) end
      remaining = remaining - 1
      if remaining == 0 and state.channel == channel and state.status == "running" then
        finish_start(#errors > 0 and table.concat(errors, "; ") or nil)
      end
    end)
  end

  requests.flush()

  if #names == 0 then finish_start() end
end

M._complete = requests.complete

M._install = function(channel, name, generation, entries)
  if channel ~= state.channel or state.status ~= "running" then error("Bunvim host is no longer active") end
  local plugin = state.plugins[name]
  if not plugin or plugin.generation ~= generation or plugin.status == "unloading" then
    error("Plugin is not active: " .. name)
  end
  registrations.install(name, generation, entries)
end

M._remove = function(channel, name, generation, id)
  if channel ~= state.channel then return end
  registrations.remove(name, generation, id)
end

local append_logs = function(lines)
  for _, line in ipairs(lines) do
    if line ~= "" then
      table.insert(state.logs, line)
      if #state.logs > 100 then table.remove(state.logs, 1) end
    end
  end
end

local handle_host_exit = function(job, code)
  if state.channel ~= job then return end

  vim_api.cancel_channel(job)
  local was_stopping = state.status == "stopping"
  close_timer(state.start_timer)
  close_timer(state.stop_timer)
  state.start_timer = nil
  state.stop_timer = nil
  state.channel = nil
  state.pid = nil
  state.status = was_stopping and "idle" or "failed"
  registrations.clear()
  local message = was_stopping and "Bunvim stopped" or state.error or "Bunvim host exited with code " .. code
  requests.clear(message)

  for _, plugin in pairs(state.plugins) do
    plugin.status = "unloaded"
  end

  if #state.start_callbacks > 0 then finish_start(message) end

  local callbacks = state.stop_callbacks
  state.stop_callbacks = {}

  for _, callback in ipairs(callbacks) do
    run_callback(callback)
  end

  if not was_stopping then
    local detail = state.logs[#state.logs]
    report_error(message .. (detail and ": " .. detail or ""))
  end
end

M.start = function(opts)
  opts = opts or {}
  if state.status == "stopping" then
    run_callback(opts.on_ready, "Bunvim is stopping")
    return
  end

  if state.status == "running" then
    if state.is_starting then
      if opts.on_ready then table.insert(state.start_callbacks, opts.on_ready) end
    else
      run_callback(opts.on_ready)
    end

    return
  end

  if opts.on_ready then table.insert(state.start_callbacks, opts.on_ready) end
  if state.status == "starting" then return end

  state.status = "starting"
  state.is_starting = true
  state.logs = {}
  local ok, channel = pcall(vim.fn.jobstart, { config.bun, root .. "/src/runner.ts" }, {
    rpc = true,
    env = { ALLOW_CONSOLE = "", NVIM_NODE_LOG_FILE = "" },
    on_stderr = function(_, lines)
      append_logs(lines)
    end,
    on_exit = handle_host_exit,
  })
  if not ok or channel <= 0 then
    state.status = "failed"
    state.error = "Could not start Bun: " .. config.bun
    finish_start(state.error)
    return
  end

  state.channel = channel
  state.pid = vim.fn.jobpid(channel)
  state.error = nil
  state.start_timer = vim.uv.new_timer()
  state.start_timer:start(
    config.startup_timeout_ms,
    0,
    vim.schedule_wrap(function()
      if state.channel ~= channel or state.status ~= "starting" then return end
      finish_start("Bunvim startup timed out")
      vim.fn.jobstop(channel)
    end)
  )
end

M.stop = function(opts)
  opts = opts or {}
  if not state.channel then
    state.status = "idle"
    run_callback(opts.on_complete)
    return
  end

  if opts.on_complete then table.insert(state.stop_callbacks, opts.on_complete) end
  if state.status == "stopping" then return end
  state.status = "stopping"
  registrations.clear()
  requests.clear("Bunvim stopped")

  close_timer(state.start_timer)
  state.start_timer = nil
  pcall(vim.rpcnotify, state.channel, "bunvim:shutdown")
  local channel = state.channel
  state.stop_timer = vim.uv.new_timer()
  state.stop_timer:start(
    config.shutdown_timeout_ms,
    0,
    vim.schedule_wrap(function()
      if state.channel == channel then vim.fn.jobstop(channel) end
    end)
  )
end

M.restart = function(opts)
  opts = opts or {}
  M.stop({
    on_complete = function()
      M.start({ on_ready = opts.on_ready })
    end,
  })
end

M.load = function(name, opts)
  if state.plugins[name] then error("Plugin is already configured: " .. name) end
  local plugin = configuration.parse_plugin(name, opts)
  state.plugins[name] = plugin
  if state.status == "running" then
    load_plugin(name, plugin, function(err, result)
      run_callback(opts.on_complete, err, result)
    end)
  else
    M.start({ on_ready = opts.on_complete })
  end
end

M.unload = function(name, opts)
  opts = opts or {}
  local plugin = state.plugins[name]
  if not plugin then
    run_callback(opts.on_complete, "Plugin is not configured: " .. name)
    return
  end

  if state.status == "running" and plugin.status ~= "failed" then
    if plugin.status == "unloading" then
      run_callback(opts.on_complete, "Plugin is already unloading: " .. name)
      return
    end

    plugin.status = "unloading"
    registrations.remove(name, plugin.generation)
    requests.cancel_plugin(name)

    requests.submit("bunvim:unload", { name }, {
      lifecycle_timeout_ms = config.unload_timeout_ms,
      on_complete = function(err)
        if state.plugins[name] == plugin then state.plugins[name] = nil end
        run_callback(opts.on_complete, err)
      end,
    })
  else
    state.plugins[name] = nil
    run_callback(opts.on_complete)
  end
end

M.call = function(name, method, opts)
  opts = opts or {}
  if type(method) ~= "string" then error("Plugin function name must be a string") end
  if not state.plugins[name] then
    run_callback(opts.on_complete, "Plugin is not configured: " .. name)
    return
  end

  if state.plugins[name].status == "unloading" then
    run_callback(opts.on_complete, "Plugin is unloading: " .. name)
    return
  end

  if state.status == "idle" or state.status == "failed" then M.start() end
  if state.status == "failed" then
    run_callback(opts.on_complete, state.error)
    return
  end

  if state.status == "stopping" then
    run_callback(opts.on_complete, "Bunvim is stopping")
    return
  end

  return requests.submit(
    "bunvim:call",
    { name, method, opts.input == nil and vim.NIL or opts.input, requests.get_origin() },
    opts
  )
end

M.call_sync = function(name, method, opts)
  opts = opts or {}
  if type(method) ~= "string" then error("Plugin function name must be a string") end
  return requests.invoke_sync(name, method, opts.input == nil and vim.NIL or opts.input, nil, nil, opts.timeout_ms)
end

M.cancel = function(id)
  return requests.cancel(id)
end

M.status = function()
  local plugins = {}
  for name, plugin in pairs(state.plugins) do
    plugins[name] = { path = plugin.path, status = plugin.status, error = plugin.error }
  end

  return {
    state = state.status,
    channel = state.channel,
    pid = state.pid,
    pending = requests.count_pending(),
    plugins = plugins,
  }
end

M.logs = function()
  return vim.deepcopy(state.logs)
end

local install_lifecycle = function()
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("bunvim.lifecycle", { clear = true }),
    callback = function()
      local channel = state.channel
      if not channel then return end

      M.stop()
      vim.fn.jobwait({ channel }, config.shutdown_timeout_ms + 100)
    end,
  })
end

local has_setup = false

M.setup = function(opts)
  opts = opts or {}
  if state.channel then error("Stop Bunvim before reconfiguring it") end

  local plugins = configuration.configure(config, opts)

  if not has_setup then
    has_setup = true
    require("bunvim.host.commands").install(M, root)
    install_lifecycle()
  end

  for name, plugin in pairs(plugins) do
    state.plugins[name] = plugin
  end

  if next(state.plugins) then M.start({ on_ready = opts.on_ready }) end
end

return M

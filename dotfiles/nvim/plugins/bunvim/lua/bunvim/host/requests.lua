local codec = require("bunvim.rpc.codec")

local validate_timeout = require("bunvim.host.configuration").validate_timeout

local create = function(state, config, run_callback)
  local close_timer = function(timer)
    if not timer or timer:is_closing() then return end
    timer:stop()
    timer:close()
  end

  local pending = {}
  local next_id = 0
  local sync_depth = 0

  local finish_request = function(id, err, result)
    local request = pending[id]
    if not request then return end
    pending[id] = nil
    close_timer(request.timer)
    run_callback(request.on_complete, err, result)
  end

  local cancel_request = function(id, reason)
    local request = pending[id]
    if not request or request.method ~= "bunvim:call" or request.is_canceled then return false end
    if request.was_sent and state.channel then
      request.is_canceled = true
      close_timer(request.timer)
      pcall(vim.rpcnotify, state.channel, "bunvim:cancel", id)
      run_callback(request.on_complete, reason or "Request canceled")
      request.on_complete = function() end
    else
      finish_request(id, reason or "Request canceled")
    end
    return true
  end

  local send_request = function(id)
    local request = pending[id]
    if not request or request.was_sent or state.status ~= "running" then return end

    local plugin = state.plugins[request.args[1]]
    if request.method == "bunvim:call" and plugin and plugin.status == "unloading" then return end

    request.was_sent = true
    local ok, send_error = pcall(function()
      local args = request.args
      if request.method == "bunvim:call" or request.method == "bunvim:load" then
        args = { unpack(args) }
        args[3] = codec.encode(args[3])
      end

      vim.rpcnotify(state.channel, request.method, id, unpack(args))
    end)
    if not ok then finish_request(id, tostring(send_error)) end
  end

  local start_deadline = function(timeout, message)
    local channel = state.channel
    local pid = state.pid
    local timer = vim.uv.new_timer()
    timer:start(timeout, 0, function()
      if state.channel ~= channel then return end
      state.error = message
      vim.uv.kill(pid, 9)
    end)
    return timer
  end

  local submit = function(method, args, opts)
    opts = opts or {}
    if opts.timeout_ms ~= nil then validate_timeout(opts.timeout_ms, "timeout_ms") end

    next_id = next_id + 1
    local id = next_id
    local request = { method = method, args = args, on_complete = opts.on_complete }
    pending[id] = request

    if opts.lifecycle_timeout_ms then
      request.timer = start_deadline(opts.lifecycle_timeout_ms, args[1] .. ": " .. method .. " timed out")
    end
    if opts.timeout_ms then
      request.timer = vim.uv.new_timer()
      request.timer:start(
        opts.timeout_ms,
        0,
        vim.schedule_wrap(function()
          cancel_request(id, "Request timed out")
        end)
      )
    end

    if state.status == "running" then send_request(id) end
    return {
      id = id,
      cancel = function()
        return cancel_request(id)
      end,
    }
  end

  local get_origin = function(bufnr)
    if not bufnr or bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
    return { bufnr, vim.api.nvim_get_current_win(), vim.fn.getcwd() }
  end

  local invoke_sync = function(name, handler, input, bufnr, generation, timeout_ms)
    local plugin = state.plugins[name]
    if state.status ~= "running" or not plugin or plugin.status ~= "loaded" then
      error("Plugin is not active: " .. name)
    end
    if generation and plugin.generation ~= generation then error("Plugin activation is no longer active: " .. name) end
    local timeout = timeout_ms or config.sync_timeout_ms
    validate_timeout(timeout, "timeout_ms")
    if sync_depth >= 32 then error("Bunvim synchronous nesting limit reached") end
    sync_depth = sync_depth + 1
    next_id = next_id + 1
    local timer = start_deadline(timeout, name .. ": synchronous call timed out")
    local ok, result = pcall(function()
      return vim.rpcrequest(
        state.channel,
        "bunvim:sync",
        next_id,
        name,
        handler,
        codec.encode(input),
        get_origin(bufnr),
        plugin.generation
      )
    end)
    close_timer(timer)
    sync_depth = sync_depth - 1
    if not ok then error(state.error or result) end
    result = codec.decode(result)
    if result == vim.NIL then return nil end
    return result
  end

  local flush = function()
    local ids = vim.tbl_keys(pending)
    table.sort(ids)
    for _, id in ipairs(ids) do
      send_request(id)
    end
  end

  local complete = function(channel, id, err, result)
    if channel ~= state.channel then return end
    if err == vim.NIL then err = nil end
    if not err then
      local ok, decoded = pcall(codec.decode, result)
      if ok then
        result = decoded
      else
        err = tostring(decoded)
        result = nil
      end
    end

    if result == vim.NIL then result = nil end
    finish_request(id, err, result)
  end

  local clear = function(message)
    for id in pairs(pending) do
      finish_request(id, message)
    end
  end

  local cancel_plugin = function(name)
    for id, request in pairs(pending) do
      if request.method == "bunvim:call" and request.args[1] == name then cancel_request(id, "Plugin unloaded") end
    end
  end

  return {
    submit = submit,
    invoke_sync = invoke_sync,
    get_origin = get_origin,
    cancel = cancel_request,
    cancel_plugin = cancel_plugin,
    complete = complete,
    flush = flush,
    clear = clear,
    count_pending = function()
      return vim.tbl_count(pending)
    end,
  }
end

return { create = create }

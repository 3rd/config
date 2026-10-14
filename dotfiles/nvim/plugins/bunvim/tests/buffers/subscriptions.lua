local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
vim.opt.runtimepath:prepend(root)
local bunvim = require("bunvim")
local errors = {}
vim.notify = function(message)
  table.insert(errors, message)
end

local wait_for = function(condition)
  assert(vim.wait(5000, condition), "subscription state did not arrive")
end

local await = function(start)
  local is_done, failure, value = false, nil, nil
  start(function(err, result)
    failure, value, is_done = err, result, true
  end)
  wait_for(function()
    return is_done
  end)
  return failure, value
end

local expect_success = function(err, result)
  assert(not err, err)
  return result
end

local call = function(plugin, method, input)
  return await(function(done)
    bunvim.call(plugin, method, { input = input, on_complete = done })
  end)
end

local load = function(name, options)
  return await(function(done)
    bunvim.load(name, { path = root .. "/tests/buffers/subscriptions-fixture.ts", options = options, on_complete = done })
  end)
end

local state = function(plugin, name)
  local states = vim.g["bunvim_subscriptions_" .. plugin]
  return states and states[name]
end

local wait_events = function(plugin, name, count)
  wait_for(function()
    local subscription = state(plugin, name)
    return subscription and #subscription.events >= count
  end)
  return state(plugin, name).events
end

local subscribe = function(plugin, name, buffer, options)
  expect_success(call(plugin, "subscribe", vim.tbl_extend("force", { name = name, buffer = buffer }, options or {})))
  return wait_events(plugin, name, 1)
end

local unload = function(name)
  return await(function(done)
    bunvim.unload(name, { on_complete = done })
  end)
end

local run = function()
  bunvim.setup({ unload_timeout_ms = 250 })
  expect_success(load("first"))
  expect_success(load("second"))
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "one", "two" })
  local events = subscribe("first", "main", buffer)
  assert(events[1].type == "snapshot" and events[1].buffer == buffer)
  assert(vim.deep_equal(events[1].lines, { "one", "two" }))
  assert(events[1].changedtick == vim.api.nvim_buf_get_changedtick(buffer))

  vim.api.nvim_buf_set_lines(buffer, 1, 2, false, { "second", "third" })
  events = wait_events("first", "main", 2)
  assert(events[2].type == "lines" and events[2].firstLine == 1 and events[2].lastLine == 2)
  assert(vim.deep_equal(events[2].lines, { "second", "third" }) and events[2].hasMore == false)
  subscribe("second", "main", buffer)
  assert(vim.deep_equal(state("second", "main").events[1].lines, { "one", "second", "third" }))
  expect_success(call("first", "dispose", "main"))
  assert(state("first", "main").reason == "disposed")
  vim.api.nvim_buf_set_lines(buffer, 0, 1, false, {})
  events = wait_events("second", "main", 2)
  assert(#events[2].lines == 0 and events[2].lastLine == 1)
  expect_success(call("first", "state"))
  assert(#state("first", "main").events == 2)
  vim.api.nvim_buf_call(buffer, function()
    vim.cmd("silent undo")
  end)
  wait_for(function()
    local updates = state("second", "main").events
    return updates[#updates].type == "changedtick"
  end)
  events = state("second", "main").events
  assert(events[#events].changedtick == vim.api.nvim_buf_get_changedtick(buffer))

  subscribe("first", "ordered", buffer, { behavior = "hold" })
  vim.api.nvim_buf_set_lines(buffer, 0, 1, false, { "held" })
  wait_for(function()
    return state("first", "ordered").isWaiting
  end)
  vim.api.nvim_buf_set_lines(buffer, 0, 1, false, { "next" })
  expect_success(call("first", "release", "ordered"))
  wait_for(function()
    return #state("first", "ordered").events == 3 and state("first", "ordered").isWaiting
  end)
  expect_success(call("first", "release", "ordered"))
  wait_for(function()
    return not state("first", "ordered").isWaiting
  end)
  events = state("first", "ordered").events
  assert(events[2].lines[1] == "held" and events[3].lines[1] == "next")
  assert(events[3].changedtick > events[2].changedtick)
  expect_success(call("first", "dispose", "ordered"))

  subscribe("first", "overflow", buffer, { behavior = "hold", maxQueued = 1 })
  vim.api.nvim_buf_set_lines(buffer, 0, 1, false, { "hold" })
  wait_for(function()
    return state("first", "overflow").isWaiting
  end)
  vim.api.nvim_buf_set_lines(buffer, 0, 1, false, { "pending" })
  vim.api.nvim_buf_set_lines(buffer, 0, 1, false, { "overflow" })
  wait_for(function()
    return state("first", "overflow").reason == "overflow" and not state("first", "overflow").isWaiting
  end)
  assert(state("first", "overflow").wasAborted and #state("first", "overflow").events == 2)
  wait_for(function()
    local latest = state("second", "main").events
    return latest[#latest].lines[1] == "overflow"
  end)

  subscribe("first", "self", buffer, { behavior = "self-dispose" })
  subscribe("first", "failure", buffer, { behavior = "fail" })
  vim.api.nvim_buf_set_lines(buffer, 0, 1, false, { "terminal" })
  wait_for(function()
    return state("first", "self").wasAborted and state("first", "failure").reason == "error"
  end)
  assert(state("first", "self").reason == "disposed")
  assert(state("first", "failure").error == "subscription handler failure")
  wait_for(function()
    return table.concat(bunvim.logs(), "\n"):find("[first:buffer:", 1, true)
  end)

  local setup_error = load("rollback", { name = "setup", buffer = buffer, shouldFail = true })
  assert(setup_error:find("subscription setup failure", 1, true))
  wait_for(function()
    return state("rollback", "setup").reason == "disposed"
  end)
  assert(vim.g.bunvim_subscriptions_disposed_rollback)
  expect_success(unload("rollback"))
  local invalid_error = call("first", "subscribe", { name = "invalid", buffer = 987654 })
  assert(invalid_error:find("Invalid buffer id", 1, true))
  local unloaded = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_delete(unloaded, { unload = true })
  local unloaded_error = call("first", "subscribe", { name = "unloaded", buffer = unloaded })
  assert(unloaded_error:find("Buffer is not loaded", 1, true))

  subscribe("first", "unload", buffer, { behavior = "hold" })
  vim.api.nvim_buf_set_lines(buffer, 0, 1, false, { "before unload" })
  wait_for(function()
    return state("first", "unload").isWaiting
  end)
  expect_success(unload("first"))
  assert(state("first", "unload").wasAborted and vim.g.bunvim_subscriptions_disposed_first)
  vim.api.nvim_buf_delete(buffer, { force = true })
  wait_for(function()
    return state("second", "main").reason == "detached"
  end)
  events = state("second", "main").events
  assert(events[#events].type == "detach")

  local file = vim.fn.tempname()
  vim.fn.writefile({ "disk" }, file)
  vim.cmd.edit(file)
  local reloaded = vim.api.nvim_get_current_buf()
  subscribe("second", "reload", reloaded)
  vim.cmd("edit!")
  wait_for(function()
    return state("second", "reload").reason == "detached"
  end)
  subscribe("second", "reattached", reloaded)
  assert(state("second", "reattached").events[1].lines[1] == "disk")
  local pid = bunvim.status().pid
  expect_success(await(function(done)
    bunvim.restart({ on_ready = done })
  end))
  assert(bunvim.status().pid ~= pid)
  subscribe("second", "restarted", reloaded, { behavior = "uncooperative" })
  vim.api.nvim_buf_set_lines(reloaded, 0, 1, false, { "uncooperative" })
  wait_for(function()
    return state("second", "restarted").isWaiting
  end)
  local unload_error = unload("second")
  assert(unload_error:find("timed out", 1, true))
  assert(bunvim.status().state == "failed")
  vim.api.nvim_buf_delete(reloaded, { force = true })
  vim.fn.delete(file)
end

local ok, failure = xpcall(run, debug.traceback)
bunvim.stop()
if not ok then
  io.stderr:write(tostring(failure) .. "\n" .. table.concat(bunvim.logs(), "\n") .. "\n")
  vim.cmd("cquit 1")
end

print("Bunvim subscriptions passed")
vim.cmd("qa!")

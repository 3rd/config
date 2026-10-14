local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
vim.opt.runtimepath:prepend(root)
local bunvim = require("bunvim")
local errors = {}
vim.notify = function(message)
  table.insert(errors, message)
end

local wait_for = function(condition)
  assert(vim.wait(5000, condition), "expected state did not arrive")
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

local succeed = function(err, result)
  assert(not err, err)
  return result
end

local call = function(name, method, input)
  return await(function(done)
    bunvim.call(name, method, { input = input, on_complete = done })
  end)
end

local load = function(name, options)
  return await(function(done)
    bunvim.load(name, { path = root .. "/tests/host/hardening-fixture.ts", options = options, on_complete = done })
  end)
end

local unload = function(name)
  return await(function(done)
    bunvim.unload(name, { on_complete = done })
  end)
end

local run = function()
  bunvim.setup({
    setup_timeout_ms = 200,
    unload_timeout_ms = 150,
    sync_timeout_ms = 150,
  })
  succeed(load("one"))
  succeed(load("two"))
  assert(bunvim.call_sync("one", "nested") == "nested")
  assert(vim.deep_equal(vim.fn.getcompletion("BunvimCompleteone a", "cmdline"), { "alpha", "amber" }))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "abc" })
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Plug>(BunvimExprone)", true, false, true), "xt", false)
  assert(vim.api.nvim_get_current_line() == "abc3")
  local saved = vim.fn.tempname() .. ".bunvim-test"
  vim.cmd("silent write! " .. vim.fn.fnameescape(saved))
  assert(vim.deep_equal(vim.fn.readfile(saved), { "saved from TypeScript" }))
  vim.api.nvim_buf_set_name(0, "")
  vim.fn.delete(saved)

  local buffer = vim.api.nvim_get_current_buf()
  assert(succeed(call("one", "create", buffer)) == 3)
  vim.cmd("BunvimRuntime" .. buffer)
  wait_for(function()
    return vim.g.bunvim_runtime_command == buffer
  end)
  vim.fn.maparg("<Plug>(BunvimRuntime)", "n", false, true).callback()
  wait_for(function()
    return vim.g.bunvim_runtime_key == buffer
  end)
  vim.api.nvim_exec_autocmds("User", { pattern = "BunvimRuntime" .. buffer })
  wait_for(function()
    return vim.g.bunvim_runtime_event == buffer
  end)
  vim.cmd("enew!")
  local second_buffer = vim.api.nvim_get_current_buf()
  assert(succeed(call("one", "create", second_buffer)) == 3)
  succeed(call("one", "remove", buffer))
  assert(#vim.api.nvim_buf_get_keymap(buffer, "n") == 0)
  assert(vim.fn.exists(":BunvimRuntime" .. buffer) == 0)
  assert(#vim.api.nvim_get_autocmds({ event = "User", pattern = "BunvimRuntime" .. buffer }) == 0)
  assert(vim.fn.maparg("<Plug>(BunvimRuntime)", "n") ~= "")
  succeed(call("one", "replace-function"))
  assert(succeed(call("one", "dynamic")) == "new")
  local failure = call("one", "fail")
  assert(failure:find("[one:fail]", 1, true) and failure:find("hardening-fixture.ts", 1, true))
  succeed(call("one", "log"))
  wait_for(function()
    return table.concat(bunvim.logs(), "\n"):find("[one:log] attributed log", 1, true)
  end)

  local requests, callbacks = {}, {}
  local completions = 0

  for value = 1, 300 do
    requests[value] = bunvim.call("one", "hold", {
      input = value,
      on_complete = function(err, result)
        callbacks[value] = err or result
        completions = completions + 1
      end,
    })
  end

  wait_for(function()
    return vim.g.bunvim_held_one == 300
  end)
  assert(succeed(call("one", "echo", "concurrent")) == "concurrent")
  assert(succeed(call("two", "echo", "independent")) == "independent")
  vim.g.bunvim_runtime_command = nil
  vim.g.bunvim_runtime_key = nil
  vim.g.bunvim_runtime_event = nil
  vim.cmd("BunvimRuntime" .. second_buffer)
  vim.fn.maparg("<Plug>(BunvimRuntime)", "n", false, true).callback()
  vim.api.nvim_exec_autocmds("User", { pattern = "BunvimRuntime" .. second_buffer })
  wait_for(function()
    return vim.g.bunvim_runtime_command == second_buffer
      and vim.g.bunvim_runtime_key == second_buffer
      and vim.g.bunvim_runtime_event == second_buffer
      and bunvim.status().pending == 300
  end)
  assert(requests[1].cancel())
  wait_for(function()
    return callbacks[1] == "Request canceled"
  end)
  assert(bunvim.status().pending == 300)
  assert(succeed(call("one", "release")) == 300)
  wait_for(function()
    return bunvim.status().pending == 0 and completions == 300
  end)
  assert(callbacks[1] == "Request canceled")

  for value = 2, 300 do
    assert(callbacks[value] == value)
  end

  local old_mapping = vim.fn.maparg("<Plug>(BunvimExprone)", "n", false, true).callback
  succeed(unload("one"))
  assert(vim.fn.exists(":BunvimRuntime" .. second_buffer) == 0)
  assert(vim.fn.maparg("<Plug>(BunvimRuntime)", "n") == "")
  succeed(load("one"))
  local is_old_mapping_active, old_mapping_error = pcall(old_mapping)
  assert(not is_old_mapping_active and tostring(old_mapping_error):find("no longer active", 1, true))
  assert(bunvim.call_sync("one", "echo", { input = "replacement" }) == "replacement")
  succeed(unload("one"))
  succeed(unload("two"))

  succeed(load("writefailure", "fail-write"))
  local failed_save = vim.fn.tempname() .. ".bunvim-test"
  local did_save, save_error = pcall(vim.cmd, "silent write! " .. vim.fn.fnameescape(failed_save))
  assert(not did_save and tostring(save_error):find("Cannot prepare this write", 1, true))
  assert(vim.fn.filereadable(failed_save) == 0)
  vim.api.nvim_buf_set_name(0, "")
  succeed(unload("writefailure"))

  succeed(load("unloading", "hang-unload"))
  local unload_error
  bunvim.unload("unloading", {
    on_complete = function(err)
      unload_error = err
    end,
  })
  local admission_error = call("unloading", "echo", "must not run")
  assert(admission_error:find("unloading", 1, true))
  wait_for(function()
    return vim.g.bunvim_unloading
  end)
  wait_for(function()
    return unload_error ~= nil
  end)
  assert(unload_error:find("timed out", 1, true))
  assert(bunvim.status().state == "failed" and bunvim.status().pending == 0)
  assert(vim.fn.exists(":BunvimCompleteunloading") == 0)

  for _, mode in ipairs({ "hang-setup", "block-setup" }) do
    local started = vim.uv.hrtime()
    local setup_error = load("setup", mode)
    assert(setup_error:find("timed out", 1, true))
    assert((vim.uv.hrtime() - started) / 1e6 < 1500)
    succeed(unload("setup"))
  end

  succeed(load("sync"))
  local started = vim.uv.hrtime()
  local ok, sync_error = pcall(bunvim.call_sync, "sync", "block")
  assert(not ok and tostring(sync_error):find("timed out", 1, true))
  assert((vim.uv.hrtime() - started) / 1e6 < 1000)
  wait_for(function()
    return bunvim.status().state == "failed"
  end)
  assert(vim.fn.exists(":BunvimCompletesync") == 0)
  succeed(unload("sync"))
  succeed(load("recovered"))
  assert(succeed(call("recovered", "echo", "recovered")) == "recovered")
  succeed(unload("recovered"))
  succeed(await(function(done)
    bunvim.stop({ on_complete = done })
  end))
end

local ok, failure = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(tostring(failure) .. "\n" .. table.concat(bunvim.logs(), "\n") .. "\n")
  bunvim.stop()
  vim.cmd("cquit 1")
end

bunvim.stop()
print("Bunvim hardening passed")
vim.cmd("qa!")

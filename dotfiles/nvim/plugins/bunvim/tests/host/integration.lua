local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
vim.opt.runtimepath:prepend(root)
local bunvim = require("bunvim")
local errors = {}
vim.notify = function(message)
  table.insert(errors, message)
end

local await = function(start)
  local is_done, failure, value = false, nil, nil
  start(function(err, result)
    failure, value, is_done = err, result, true
  end)
  assert(
    vim.wait(5000, function()
      return is_done
    end),
    "callback did not complete"
  )
  return failure, value
end

local call = function(method, input)
  return await(function(done)
    bunvim.call("fixture", method, { input = input, on_complete = done })
  end)
end

local expect_success = function(err, value)
  assert(not err, err)
  return value
end

local wait_for = function(condition)
  assert(vim.wait(5000, condition), "expected editor state did not arrive")
end

local run = function()
  bunvim.setup()
  assert(bunvim.status().state == "idle" and not bunvim.status().pid)
  expect_success(await(function(done)
    bunvim.load("fixture", { path = root .. "/tests/host/fixture.ts", on_complete = done })
  end))
  local pid = bunvim.status().pid
  assert(expect_success(call("echo", "hello")) == "hello")
  assert(expect_success(call("echo", false)) == false)
  assert(expect_success(call("count")) == 1)
  assert(expect_success(call("count")) == 2)
  assert(bunvim.status().pid == pid)
  assert(call("echo", {}):find("expected string or boolean", 1, true))
  assert(call("missing"):find("Unknown plugin function", 1, true))
  assert(call("fail"):find("fixture handler failure", 1, true))
  assert(call("invalid"):find("Plugin results must be", 1, true))
  assert(expect_success(call("log")))
  wait_for(function()
    return table.concat(bunvim.logs(), "\n"):find("fixture log", 1, true)
  end)

  vim.cmd("BunvimFixture! alpha beta")
  wait_for(function()
    return vim.g.bunvim_command ~= nil
  end)
  assert(vim.g.bunvim_command.args == "alpha beta" and vim.g.bunvim_command.bang)
  assert(vim.g.bunvim_command.buffer == vim.api.nvim_get_current_buf())
  local mapping = vim.fn.maparg("<Plug>(BunvimFixture)", "n", false, true)
  mapping.callback()
  wait_for(function()
    return vim.g.bunvim_key ~= nil
  end)
  assert(vim.g.bunvim_key == vim.api.nvim_get_current_buf())
  vim.api.nvim_exec_autocmds("User", { pattern = "BunvimFixtureEvent", data = "payload" })
  wait_for(function()
    return vim.g.bunvim_event ~= nil
  end)
  assert(vim.g.bunvim_event.count == 3 and vim.g.bunvim_event.data == "payload")

  local completions, cancellation = 0, nil
  local request = bunvim.call("fixture", "wait", {
    on_complete = function(err)
      completions = completions + 1
      cancellation = err
    end,
  })
  wait_for(function()
    return vim.g.bunvim_waiting
  end)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "editor stays responsive" })
  assert(request.cancel())
  wait_for(function()
    return cancellation ~= nil
  end)
  assert(cancellation == "Request canceled" and not request.cancel())
  assert(expect_success(call("echo", "after cancellation")) == "after cancellation")
  assert(completions == 1)
  local timeout_error = await(function(done)
    bunvim.call("fixture", "wait", { timeout_ms = 20, on_complete = done })
  end)
  assert(timeout_error == "Request timed out")

  local stale_error
  bunvim.call("fixture", "edit", {
    on_complete = function(err)
      stale_error = err
    end,
  })
  wait_for(function()
    return vim.g.bunvim_snapshot
  end)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "user edit" })
  expect_success(call("release"))
  wait_for(function()
    return stale_error ~= nil
  end)
  assert(stale_error:find("Buffer changed", 1, true))
  assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "user edit")

  local collision = await(function(done)
    bunvim.load("collision", { path = root .. "/tests/host/fixture.ts", on_complete = done })
  end)
  assert(collision:find("already exists", 1, true))
  assert(vim.fn.exists(":BunvimFixture") == 2)
  assert(vim.fn.exists(":BunvimFixturePartialcollision") == 0)
  expect_success(await(function(done)
    bunvim.unload("collision", { on_complete = done })
  end))
  local original_buffer = vim.api.nvim_get_current_buf()
  vim.cmd("enew!")
  vim.api.nvim_create_user_command("BunvimFixturePartialfixture", function() end, {})
  expect_success(await(function(done)
    bunvim.unload("fixture", { on_complete = done })
  end))
  assert(vim.g.bunvim_disposed and vim.api.nvim_get_commands({}).BunvimFixture == nil)
  assert(vim.fn.exists(":BunvimFixturePartialfixture") == 2)
  vim.api.nvim_del_user_command("BunvimFixturePartialfixture")
  assert(#vim.api.nvim_buf_get_keymap(original_buffer, "n") == 0)
  assert(vim.fn.maparg("<Plug>(BunvimFixture)", "n") == "")
  assert(#vim.api.nvim_get_autocmds({ event = "User", pattern = "BunvimFixtureEvent" }) == 0)

  local setup_error = await(function(done)
    bunvim.load("failure", { path = root .. "/tests/host/fixture.ts", options = "fail", on_complete = done })
  end)
  assert(setup_error:find("fixture setup failure", 1, true))
  assert(vim.fn.exists(":BunvimFixturePartialfailure") == 0)
  expect_success(await(function(done)
    bunvim.unload("failure", { on_complete = done })
  end))
  expect_success(await(function(done)
    bunvim.load("fixture", { path = root .. "/tests/host/fixture.ts", on_complete = done })
  end))
  expect_success(await(function(done)
    bunvim.restart({ on_ready = done })
  end))
  assert(bunvim.status().pid ~= pid and expect_success(call("count")) == 1)
  local crash_error = call("exit")
  assert(crash_error:find("exited with code 23", 1, true))
  assert(bunvim.status().state == "failed" and vim.fn.exists(":BunvimFixture") == 0)
  assert(expect_success(call("count")) == 1)
  expect_success(await(function(done)
    bunvim.stop({ on_complete = done })
  end))
  assert(bunvim.status().state == "idle" and bunvim.status().pending == 0)

  bunvim.setup({ bun = "/nonexistent/bunvim-bun" })
  local start_error = await(function(done)
    bunvim.start({ on_ready = done })
  end)
  assert(start_error:find("Could not start Bun", 1, true))
  local launch_error = call("count")
  assert(launch_error:find("Could not start Bun", 1, true))
  bunvim.setup({ bun = "bun" })
  expect_success(await(function(done)
    bunvim.stop({ on_complete = done })
  end))
  assert(bunvim.status().state == "idle")
end

local ok, failure = xpcall(run, debug.traceback)
bunvim.stop()
if not ok then
  io.stderr:write(tostring(failure) .. "\n" .. table.concat(bunvim.logs(), "\n") .. "\n")
  vim.cmd("cquit 1")
end

print("Bunvim integration passed")
vim.cmd("qa!")

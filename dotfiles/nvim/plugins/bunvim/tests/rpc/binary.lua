local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
vim.opt.runtimepath:prepend(root)
local bunvim = require("bunvim")

local wait_for = function(condition)
  assert(vim.wait(5000, condition), "Binary fixture result missing")
end

local start_call = function(method, input)
  local result = { is_done = false, completions = 0 }
  result.request = assert(bunvim.call("binary", method, {
    input = input,
    on_complete = function(err, value)
      result.error, result.value, result.is_done = err, value, true
      result.completions = result.completions + 1
    end,
  }))
  return result
end

local call = function(method, input)
  local result = start_call(method, input)
  wait_for(function()
    return result.is_done
  end)
  assert(not result.error, result.error)
  return result.value
end

local run = function()
  local bytes = string.char(0, 128, 192, 255)
  bunvim.setup()
  local is_loaded, load_error = false, nil
  bunvim.load("binary", {
    path = root .. "/tests/rpc/binary-fixture.ts",
    options = { bytes = bunvim.bytes(bytes), text = "héllo 🐇" },
    on_complete = function(err)
      is_loaded, load_error = true, err
    end,
  })
  wait_for(function()
    return is_loaded
  end)
  assert(not load_error, load_error)

  local input = { bytes = bunvim.bytes(bytes), text = "héllo 🐇", tag = { "bytes", "AIDA/w==" } }
  local echoed = call("echo", input)
  assert(bunvim.bytes_value(echoed.bytes) == bytes and echoed.text == input.text)
  assert(vim.deep_equal(echoed.tag, input.tag))
  local sync = bunvim.call_sync("binary", "echo", { input = echoed })
  assert(bunvim.bytes_value(sync.bytes) == bytes and sync.text == input.text)
  local options = call("options")
  assert(bunvim.bytes_value(options.bytes) == bytes and options.text == input.text)
  local slice = call("slice")
  assert(bunvim.bytes_value(slice.bytes) == bytes and slice.text == input.text)
  assert(bunvim.bytes_value(slice.empty) == "" and slice["nil"] == vim.NIL)

  local result = call("file", vim.env.XDG_STATE_HOME .. "/binary.dat")
  assert(result.written[1] == 7 and result.written[2] == vim.NIL and result.written[3] == vim.NIL)
  assert(bunvim.bytes_value(result.read[1]) == bytes .. "hé")
  assert(result.read[2] == vim.NIL and result.read[3] == vim.NIL)
  assert(bunvim.bytes_value(result.eof[1]) == "")
  local failed = call("readError")
  assert(failed[1] == vim.NIL and failed[2]:find("EBADF", 1, true) and failed[3] == "EBADF")
  local random = call("random")
  assert(#bunvim.bytes_value(random[1]) == 32 and random[2] == vim.NIL and random[3] == vim.NIL)

  local original_interfaces = vim.uv.interface_addresses
  vim.uv.interface_addresses = function()
    return {
      fixture = { { ip = "127.0.0.1", family = "inet", netmask = "255.0.0.0", internal = true, mac = bytes } },
    }
  end
  local interfaces = call("interfaces")
  vim.uv.interface_addresses = original_interfaces
  assert(bunvim.bytes_value(interfaces[1].fixture[1].mac) == bytes)
  assert(interfaces[1].fixture[1].ip == "127.0.0.1" and interfaces[1].fixture[1].internal)
  local converted = call("convert")
  assert(bunvim.bytes_value(converted.wtf8) == string.char(237, 160, 128))
  assert(bunvim.bytes_value(converted.utf16) == bunvim.bytes_value(converted.roundTrip))
  assert(converted.utf16Length == 1 and converted.wtf8Length == 3)

  local original_random = vim.uv.random
  local callback
  vim.uv.random = function(_, _, complete)
    callback = complete
    return 0
  end
  local canceled = start_call("random")
  wait_for(function()
    return callback ~= nil
  end)
  assert(canceled.request.cancel())
  wait_for(function()
    return canceled.is_done
  end)
  call("barrier")
  callback(nil, bytes)
  call("barrier")
  assert(canceled.error == "Request canceled" and canceled.completions == 1)
  vim.uv.random = original_random

  local is_stopped = false
  bunvim.stop({
    on_complete = function(err)
      assert(not err, err)
      is_stopped = true
    end,
  })
  wait_for(function()
    return is_stopped
  end)
end

local ok, err = xpcall(run, debug.traceback)
bunvim.stop()

if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end

io.stdout:write("Bunvim binary passed\n")
vim.cmd("qa!")

local directory = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
vim.opt.runtimepath:prepend(directory .. "/../..")
local bunvim = require("bunvim")

local await = function(start)
  local is_done, failure = false, nil
  start(function(err)
    failure, is_done = err, true
  end)
  assert(
    vim.wait(5000, function()
      return is_done
    end),
    "Format callback missing"
  )
  assert(not failure, failure)
end

local run = function()
  local errors = {}
  vim.notify = function(message, level)
    assert(level == vim.log.levels.ERROR)
    table.insert(errors, message)
  end
  await(function(done)
    bunvim.load("format-json", { path = directory .. "/index.ts", on_complete = done })
  end)

  local run_command = function(command)
    vim.cmd(command)
    assert(vim.wait(5000, function()
      return bunvim.status().pending == 0
    end))
  end

  local source = vim.api.nvim_get_current_buf()
  local original = { '{"name":"sample","enabled":true}' }
  vim.api.nvim_buf_set_lines(source, 0, -1, false, original)
  vim.bo[source].undolevels = vim.bo[source].undolevels
  run_command("FormatJSON")
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(source, 0, -1, false), {
    "{",
    '  "name": "sample",',
    '  "enabled": true',
    "}",
  }))
  vim.cmd("silent undo")
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(source, 0, -1, false), original))

  vim.api.nvim_buf_set_lines(source, 0, -1, false, { "before", '{"value":1}', "after" })
  run_command("2,2FormatJSON")
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(source, 0, -1, false), {
    "before",
    "{",
    '  "value": 1',
    "}",
    "after",
  }))

  local invalid = { '{"unfinished":' }
  vim.api.nvim_buf_set_lines(source, 0, -1, false, invalid)
  run_command("FormatJSON")
  assert(#errors == 1)
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(source, 0, -1, false), invalid))

  local editor = require("bunvim.editor")
  local read = editor.read
  local other = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(source, 0, -1, false, { '{"value":2}' })
  editor.read = function(...)
    local snapshot = read(...)
    vim.api.nvim_set_current_buf(other)
    return snapshot
  end
  run_command("FormatJSON")
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(source, 0, -1, false), { "{", '  "value": 2', "}" }))
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(other, 0, -1, false), { "" }))
  assert(#errors == 1)

  vim.api.nvim_set_current_buf(source)
  vim.api.nvim_buf_set_lines(source, 0, -1, false, { '{"value":3}' })
  editor.read = function(...)
    local snapshot = read(...)
    vim.api.nvim_buf_set_lines(source, 0, -1, false, { "newer text" })
    return snapshot
  end
  run_command("FormatJSON")
  editor.read = read
  assert(#errors == 2 and errors[2]:find("Buffer changed while the operation was running", 1, true))
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(source, 0, -1, false), { "newer text" }))
  await(function(done)
    bunvim.unload("format-json", { on_complete = done })
  end)
  assert(vim.fn.exists(":FormatJSON") == 0)
  await(function(done)
    bunvim.stop({ on_complete = done })
  end)
end

local ok, failure = xpcall(run, debug.traceback)
bunvim.stop()
if not ok then
  io.stderr:write(tostring(failure) .. "\n" .. table.concat(bunvim.logs(), "\n") .. "\n")
  vim.cmd("cquit 1")
end

print("Format JSON passed")
vim.cmd("qa!")

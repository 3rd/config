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
    "TODO callback missing"
  )
  assert(not failure, failure)
end

local run = function()
  local messages = {}
  vim.notify = function(message)
    table.insert(messages, message)
  end
  await(function(done)
    bunvim.load("todo-list", { path = directory .. "/index.ts", on_complete = done })
  end)

  local run_command = function()
    vim.cmd("TodoList")
    assert(vim.wait(5000, function()
      return bunvim.status().pending == 0
    end))
  end

  local source = vim.api.nvim_get_current_buf()
  local lines = { "// TODO: add tests", "const METHODODO = 1", "// café FIXME: handle errors", "// TODO and FIXME" }
  vim.api.nvim_buf_set_lines(source, 0, -1, false, lines)
  local other = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(other, 0, -1, false, { "TODO: another buffer" })
  local editor = require("bunvim.editor")
  local read = editor.read
  editor.read = function(...)
    local snapshot = read(...)
    vim.api.nvim_set_current_buf(other)
    return snapshot
  end
  run_command()
  editor.read = read
  local list = vim.fn.getqflist({ title = 0, items = 0, winid = 0 })
  assert(list.title == "TODO/FIXME" and list.winid ~= 0)
  assert(#list.items == 3)

  for index, row in ipairs({ 1, 3, 4 }) do
    local item = list.items[index]
    assert(item.bufnr == source and item.lnum == row and item.text == lines[row])
    assert(item.col == (row == 3 and 10 or 4))
  end

  vim.cmd("silent cc 2")
  assert(vim.api.nvim_get_current_buf() == source)
  assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 3, 9 }))

  vim.cmd("cclose")
  vim.api.nvim_buf_set_lines(source, 0, -1, false, { "No markers here" })
  run_command()
  assert(#vim.fn.getqflist() == 0)
  assert(vim.fn.getqflist({ winid = 0 }).winid == 0)
  assert(messages[#messages] == "No TODO or FIXME markers in this buffer.")
  await(function(done)
    bunvim.unload("todo-list", { on_complete = done })
  end)
  assert(vim.fn.exists(":TodoList") == 0)
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

print("TODO list passed")
vim.cmd("qa!")

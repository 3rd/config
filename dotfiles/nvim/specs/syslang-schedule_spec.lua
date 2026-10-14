local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(root .. "/plugins/syslang")
vim.opt.runtimepath:prepend(root .. "/plugins/bunvim")
vim.opt.runtimepath:prepend(root .. "/plugins/bunmods")
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/site")
require("lib")
local bunvim = require("bunvim")
local errors = {}
vim.notify = function(message)
  table.insert(errors, message)
end

local wait_for = function(condition)
  assert(vim.wait(5000, condition), "Schedule result missing")
end

local await = function(start)
  local is_done, failure, value = false, nil, nil
  start(function(err, result)
    failure, value, is_done = err, result, true
  end)
  wait_for(function()
    return is_done
  end)
  assert(not failure, failure)
  return value
end

local wait_for_calls = function()
  wait_for(function()
    return bunvim.status().pending == 0
  end)
  local did_dispatch = false
  vim.schedule(function()
    did_dispatch = true
  end)
  wait_for(function()
    return did_dispatch
  end)
end

local run = function()
  vim.bo.filetype = "syslang"
  vim.bo.shiftwidth = 2
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[ ] Prepare test report", "" })
  assert(not vim.treesitter.get_parser(0, "syslang"):parse()[1]:root():has_error())
  require("syslang").setup()
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  require("bunmods").setup()
  await(function(done)
    bunvim.start({ on_ready = done })
  end)
  local submit = function(input, after_submit)
    local did_prompt = false
    vim.ui.input = function(options, done)
      assert(options.prompt == "Schedule: ")
      done(input)

      if after_submit then after_submit() end

      did_prompt = true
    end
    local mapping = vim.fn.maparg("<leader>es", "n", false, true)
    assert(type(mapping.callback) == "function")
    mapping.callback()
    wait_for(function()
      return did_prompt
    end)
  end

  submit("October 14, 2026 at 9:30am")
  wait_for(function()
    return vim.api.nvim_buf_get_lines(0, 1, 2, false)[1] == "  Schedule: 2026.10.14 09:30"
  end)
  vim.api.nvim_win_set_cursor(0, { 2, 3 })
  submit("October 15, 2026")
  wait_for(function()
    return vim.api.nvim_buf_get_lines(0, 1, 2, false)[1] == "  Schedule: 2026.10.15"
  end)
  local scheduled_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  submit("not a date")
  wait_for_calls()
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), scheduled_lines))
  submit(nil)
  wait_for_calls()
  submit("")
  wait_for_calls()
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), scheduled_lines))
  assert(bunvim.call_sync("chrono", "toSchedule", { input = "not a date" }) == nil)
  local is_valid, failure = pcall(bunvim.call_sync, "chrono", "toSchedule", { input = {} })
  assert(not is_valid and failure:find("Schedule input must be a string", 1, true))

  submit("October 16, 2026", function()
    vim.bo.filetype = "text"
  end)
  wait_for_calls()
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), scheduled_lines))
  vim.bo.filetype = "syslang"

  submit("October 16, 2026", function()
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end)
  wait_for_calls()
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), scheduled_lines))

  submit("October 16, 2026", function()
    vim.api.nvim_set_current_line("[ ] User changed the task")
  end)
  local edited_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  wait_for_calls()
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), edited_lines))

  local target = vim.api.nvim_get_current_buf()
  submit("October 16, 2026", function()
    vim.cmd("enew!")
  end)
  wait_for_calls()
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(target, 0, -1, false), edited_lines))
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "" }))
  assert(vim.tbl_isempty(vim.fn.maparg("<leader>es", "n", false, true)))

  vim.bo.filetype = "syslang"
  vim.bo.shiftwidth = 4
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "[ ] Prepare another report",
    "    Session: 2026.10.12 09:00-10:00",
    "    Schedule: 2026.10.13",
    "    Notes for the report",
    "",
  })
  assert(not vim.treesitter.get_parser(0, "syslang"):parse()[1]:root():has_error())
  wait_for_calls()
  require("syslang").setup()
  submit("October 17, 2026")
  wait_for(function()
    return vim.api.nvim_buf_get_lines(0, 3, 4, false)[1] == "    Schedule: 2026.10.17"
  end)
  assert(vim.api.nvim_buf_get_lines(0, 4, 5, false)[1] == "    Notes for the report")

  local schedule_buffer = vim.api.nvim_get_current_buf()
  vim.cmd("enew!")
  vim.bo.filetype = "syslang"
  require("syslang").setup()
  wait_for_calls()
  assert(type(vim.fn.maparg("<leader>es", "n", false, true).callback) == "function")
  vim.api.nvim_buf_delete(0, { force = true })
  vim.api.nvim_set_current_buf(schedule_buffer)
  wait_for_calls()

  local open_prompt = function()
    local complete
    vim.ui.input = function(_, done)
      complete = done
    end
    local mapping = vim.fn.maparg("<leader>es", "n", false, true)
    assert(type(mapping.callback) == "function")
    mapping.callback()
    wait_for(function()
      return type(complete) == "function"
    end)
    return complete
  end

  local before_reload = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local complete_old_prompt = open_prompt()
  await(function(done)
    bunvim.unload("chrono", { on_complete = done })
  end)
  assert(type(vim.fn.maparg("<leader>es", "n", false, true).callback) == "function")
  await(function(done)
    bunvim.load("chrono", { path = root .. "/plugins/bunmods/src/chrono/index.ts", on_complete = done })
  end)
  complete_old_prompt("October 18, 2026")
  wait_for_calls()
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), before_reload))

  local complete_before_restart = open_prompt()
  await(function(done)
    bunvim.restart({ on_ready = done })
  end)
  complete_before_restart("October 18, 2026")
  wait_for_calls()
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), before_reload))
  vim.api.nvim_win_set_cursor(0, { 4, 5 })
  submit("October 19, 2026")
  wait_for(function()
    return vim.api.nvim_buf_get_lines(0, 3, 4, false)[1] == "    Schedule: 2026.10.19"
  end)
  assert(bunvim.call_sync("chrono", "toSchedule", { input = "October 16, 2026" }) == "2026.10.16")
  local replacement = function() end
  vim.keymap.set("n", "<leader>es", replacement, { buffer = true })
  await(function(done)
    bunvim.stop({ on_complete = done })
  end)
  assert(vim.fn.maparg("<leader>es", "n", false, true).callback == replacement)
  assert(#errors == 0, table.concat(errors, "\n"))
end

local ok, failure = xpcall(run, debug.traceback)
bunvim.stop()
if not ok then
  io.stderr:write(tostring(failure) .. "\n" .. table.concat(bunvim.logs(), "\n") .. "\n")
  vim.cmd("cquit 1")
end

print("Syslang schedules passed")
vim.cmd("qa!")

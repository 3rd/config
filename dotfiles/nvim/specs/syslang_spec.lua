require("lib")

vim.opt.runtimepath:append(vim.fn.getcwd() .. "/plugins/syslang")

local syslang = require("syslang")
local wiki = require("modules.wiki.api")

local create_syslang_buffer = function(lines)
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "syslang"
  vim.bo[bufnr].tabstop = 2
  vim.bo[bufnr].shiftwidth = 2
  syslang.setup()
  return bufnr
end

local mapping_callback = function(lhs)
  local mapping = vim.fn.maparg(lhs, "n", false, true)
  assert(type(mapping.callback) == "function", "missing Syslang mapping " .. lhs)
  return mapping.callback
end

local parse = function(bufnr)
  local trees = vim.treesitter.get_parser(bufnr, "syslang"):parse()
  assert(trees[1], "Syslang parser returned no tree")
  return trees[1]:root()
end

local task_buffer = create_syslang_buffer({ "  write tests" })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
mapping_callback("<C-Space>")()
assert(vim.api.nvim_get_current_line() == "  [ ] write tests", "task creation did not preserve indentation")
assert(vim.api.nvim_win_get_cursor(0)[2] == 6, "task creation did not keep the cursor on the same text character")

local blank_buffer = create_syslang_buffer({ "   " })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
mapping_callback("<C-Space>")()
assert(vim.api.nvim_get_current_line() == "   ", "task creation changed a whitespace-only line")

local cycle_buffer = create_syslang_buffer({ "# Tasks", "[ ] write tests" })
vim.api.nvim_win_set_cursor(0, { 2, 5 })
parse(cycle_buffer)
mapping_callback("<C-Space>")()
assert(vim.api.nvim_get_current_line() == "[-] write tests", "default task did not become active")

local original_date = os.date
os.date = function(format)
  if format == "%Y.%m.%d %H:%M-%H:%M" then return "2026.08.09 12:34-12:34" end
  if format == "%Y.%m.%d" then return "2026.08.09" end
  if format == "%H:%M" then return "12:34" end
  return original_date(format)
end

parse(cycle_buffer)
mapping_callback("<C-Space>")()
local task_lines = vim.api.nvim_buf_get_lines(cycle_buffer, 0, -1, false)
assert(task_lines[2] == "[x] write tests", "active task did not become done")
assert(
  task_lines[3] == "  Session: 2026.08.09 12:34-12:34",
  "completed task has the wrong session: " .. vim.inspect(task_lines)
)

local first_line_active_buffer = create_syslang_buffer({ "[-] first-line task" })
local first_line_root = parse(first_line_active_buffer)
assert(first_line_root:named_child(0):type() == "task_active", "line 1 active task did not parse as a task")
vim.api.nvim_win_set_cursor(0, { 1, 8 })
mapping_callback("<C-Space>")()
local first_line_task_lines = vim.api.nvim_buf_get_lines(first_line_active_buffer, 0, -1, false)
assert(
  vim.deep_equal(first_line_task_lines, { "[x] first-line task", "  Session: 2026.08.09 12:34-12:34" }),
  "line 1 active task did not complete with an instant session: " .. vim.inspect(first_line_task_lines)
)

local empty_active_buffer = create_syslang_buffer({ "[-] " })
local empty_active_root = parse(empty_active_buffer)
assert(empty_active_root:has_error(), "empty active task no longer exercises the parser-error fallback")
vim.api.nvim_win_set_cursor(0, { 1, 3 })
mapping_callback("<C-Space>")()
local empty_active_lines = vim.api.nvim_buf_get_lines(empty_active_buffer, 0, -1, false)
assert(
  vim.deep_equal(empty_active_lines, { "[x] ", "  Session: 2026.08.09 12:34-12:34" }),
  "empty active task did not complete with an instant session: " .. vim.inspect(empty_active_lines)
)

local reordered_eof_buffer = create_syslang_buffer({ "[x] done", "[ ] pending", "[-] finish me" })
vim.bo[reordered_eof_buffer].shiftwidth = 4
parse(reordered_eof_buffer)
vim.api.nvim_win_set_cursor(0, { 3, 8 })
mapping_callback("<C-Space>")()
local reordered_eof_lines = vim.api.nvim_buf_get_lines(reordered_eof_buffer, 0, -1, false)
assert(
  vim.deep_equal(reordered_eof_lines, {
    "[x] done",
    "[x] finish me",
    "    Session: 2026.08.09 12:34-12:34",
    "[ ] pending",
  }),
  "EOF task completion changed sorting or added a blank line: " .. vim.inspect(reordered_eof_lines)
)
local reordered_cursor = vim.api.nvim_win_get_cursor(0)
assert(vim.deep_equal(reordered_cursor, { 2, 8 }), "reordered task did not preserve its logical cursor position")
assert(vim.api.nvim_get_current_line():sub(9, 9) == "s", "reordered task cursor no longer points at the same text")

parse(cycle_buffer)
vim.api.nvim_set_current_buf(cycle_buffer)
vim.api.nvim_win_set_cursor(0, { 2, 5 })
mapping_callback("<C-Space>")()
task_lines = vim.api.nvim_buf_get_lines(cycle_buffer, 0, -1, false)
assert(vim.deep_equal(task_lines, { "# Tasks", "[ ] write tests" }), "done task did not return to its default state")
os.date = original_date

local cancelled_buffer = create_syslang_buffer({ "[ ] cancelled task" })
parse(cancelled_buffer)
mapping_callback("<C-C>")()
assert(vim.api.nvim_get_current_line() == "[_] cancelled task", "default task did not become cancelled")
parse(cancelled_buffer)
mapping_callback("<C-C>")()
assert(vim.api.nvim_get_current_line() == "[ ] cancelled task", "cancelled task did not return to default")

local schedule_buffer = create_syslang_buffer({ "[ ] scheduled task" })
vim.bo[schedule_buffer].shiftwidth = 4
local original_input = vim.ui.input
local original_to_schedule = lib.node.chrono.to_schedule
vim.ui.input = function(_, callback)
  callback("tomorrow")
end
lib.node.chrono.to_schedule = function(input)
  assert(input == "tomorrow", "schedule input changed before parsing")
  return "2026.08.10"
end

parse(schedule_buffer)
mapping_callback("<leader>es")()
local schedule_lines = vim.api.nvim_buf_get_lines(schedule_buffer, 0, -1, false)
assert(
  vim.deep_equal(schedule_lines, { "[ ] scheduled task", "    Schedule: 2026.08.10" }),
  "task scheduling did not add a child schedule"
)

lib.node.chrono.to_schedule = function()
  return "2026.08.11"
end
parse(schedule_buffer)
vim.api.nvim_win_set_cursor(0, { 2, 4 })
mapping_callback("<leader>es")()
schedule_lines = vim.api.nvim_buf_get_lines(schedule_buffer, 0, -1, false)
assert(schedule_lines[2] == "    Schedule: 2026.08.11", "task scheduling did not update an existing schedule")
vim.ui.input = original_input
lib.node.chrono.to_schedule = original_to_schedule

local winbar_buffer = create_syslang_buffer({ "@meta", "  title: Old title", "@end", "body" })
parse(winbar_buffer)
local initial_winbar = vim.wo.winbar
assert(initial_winbar:find("Old title", 1, true), "winbar did not use the parsed document title")

vim.wo.winbar = "unchanged body winbar"
local original_get_lines = vim.api.nvim_buf_get_lines
local body_change_full_buffer_reads = 0
vim.api.nvim_buf_get_lines = function(bufnr, start_row, end_row, ...)
  if bufnr == winbar_buffer and start_row == 0 and end_row == -1 then
    body_change_full_buffer_reads = body_change_full_buffer_reads + 1
  end
  return original_get_lines(bufnr, start_row, end_row, ...)
end
vim.api.nvim_buf_set_text(winbar_buffer, 3, 4, 3, 4, { " changed" })
vim.api.nvim_exec_autocmds("TextChanged", { buffer = winbar_buffer })
vim.api.nvim_buf_get_lines = original_get_lines
assert(vim.wo.winbar == "unchanged body winbar", "body text change reparsed the winbar title")
assert(body_change_full_buffer_reads == 0, "body text change scanned the buffer for winbar metadata")

vim.wo.winbar = initial_winbar
vim.api.nvim_buf_set_text(winbar_buffer, 1, 9, 1, 18, { "New title" })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = winbar_buffer })
assert(vim.wo.winbar == initial_winbar, "insert-mode text change reparsed the winbar title")
vim.api.nvim_exec_autocmds("InsertLeave", { buffer = winbar_buffer })
assert(vim.wo.winbar:find("New title", 1, true), "winbar did not refresh at the metadata edit boundary")

local added_meta_buffer = create_syslang_buffer({ "body" })
vim.api.nvim_buf_set_lines(added_meta_buffer, 0, 0, false, { "@meta", "title: Added title", "@end" })
vim.api.nvim_exec_autocmds("InsertLeave", { buffer = added_meta_buffer })
assert(vim.wo.winbar:find("Added title", 1, true), "winbar did not detect newly added metadata")
vim.api.nvim_buf_set_lines(added_meta_buffer, 0, 3, false, {})
vim.api.nvim_exec_autocmds("TextChanged", { buffer = added_meta_buffer })
assert(not vim.wo.winbar:find("Added title", 1, true), "winbar kept a title from removed metadata")

local move_buffer = create_syslang_buffer({ "- first", "  - child", "- second" })
parse(move_buffer)
vim.api.nvim_win_set_cursor(0, { 1, 3 })
mapping_callback("<M-j>")()
assert(
  vim.deep_equal(vim.api.nvim_buf_get_lines(move_buffer, 0, -1, false), { "- second", "- first", "  - child" }),
  "moving a list item did not preserve its subtree"
)
assert(vim.api.nvim_win_get_cursor(0)[1] == 2, "moving a list item did not follow it with the cursor")

local outline_buffer = create_syslang_buffer({ "* Parent", "  ** Child" })
vim.bo[outline_buffer].expandtab = true
parse(outline_buffer)
vim.api.nvim_win_set_cursor(0, { 1, 2 })
mapping_callback(">")()
assert(
  vim.deep_equal(vim.api.nvim_buf_get_lines(outline_buffer, 0, -1, false), { "  ** Parent", "    *** Child" }),
  "Syslang > mapping did not demote the outline subtree: "
    .. vim.inspect(vim.api.nvim_buf_get_lines(outline_buffer, 0, -1, false))
)
mapping_callback("<")()
assert(
  vim.deep_equal(vim.api.nvim_buf_get_lines(outline_buffer, 0, -1, false), { "* Parent", "  ** Child" }),
  "Syslang < mapping did not promote the outline subtree"
)

local original_resolve_node = wiki.resolve_node
local resolved_id
wiki.resolve_node = function(id)
  resolved_id = id
  return "/tmp/syslang wiki target.plm"
end
local link_buffer = create_syslang_buffer({ "[[Some Node]]" })
parse(link_buffer)
vim.api.nvim_win_set_cursor(0, { 1, 4 })
mapping_callback("<CR>")()
assert(resolved_id == "some-node", "Syslang internal links use the wrong wiki node id")
assert(vim.api.nvim_buf_get_name(0) == "/tmp/syslang wiki target.plm", "Syslang internal link opened the wrong path")
wiki.resolve_node = original_resolve_node

local autocmds = vim.api.nvim_get_autocmds({ group = "syslang:folds" })
local fold_buffers = {}
for _, autocmd in ipairs(autocmds) do
  if autocmd.buffer then fold_buffers[autocmd.buffer] = true end
end
assert(fold_buffers[task_buffer], "opening later Syslang buffers removed the first buffer's fold autocmds")
assert(fold_buffers[link_buffer], "the latest Syslang buffer has no fold autocmds")

print("ok: Syslang task, schedule, movement, winbar, link, and fold behavior")

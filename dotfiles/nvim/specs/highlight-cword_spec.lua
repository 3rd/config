require("lib")

vim.cmd.colorscheme("static")
vim.opt.ignorecase = true
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Before reading", "For every match", "for each word" })
vim.bo.filetype = "text"
vim.api.nvim_win_set_cursor(0, { 2, 0 })
require("modules/misc/highlight-cword").setup()
vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
assert(
  vim.wait(1000, function()
    return #vim.fn.getmatches() == 2
  end),
  "cursor-word highlights did not appear"
)

local priorities = {}

for _, match in ipairs(vim.fn.getmatches()) do
  priorities[match.group] = match.priority
end

assert(priorities.CursorWord, "other occurrences must retain cursor-word highlighting")
assert(priorities.CursorWordCurrent, "the current occurrence must retain cursor-word highlighting")
assert(priorities.CursorWord < 0, "other cursor-word occurrences must yield to search highlighting at priority zero")
assert(priorities.CursorWordCurrent < 0, "the current cursor word must yield to search highlighting at priority zero")

print("ok: current and other cursor-word highlights yield to search highlighting")

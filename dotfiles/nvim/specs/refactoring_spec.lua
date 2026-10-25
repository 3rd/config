require("lib")
vim.opt.runtimepath:prepend(lib.env.dirs.vim.lazy.root .. "/refactoring.nvim")
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/site")
vim.cmd.runtime("plugin/ts.lua")
require("modules.language-support.refactoring").plugins[1].config()

local refactoring = require("refactoring")
for _, mode in ipairs({ "n", "x" }) do
  assert(vim.fn.maparg("<leader>if", mode) == "", "unsafe function inlining must not have a shortcut")
  local mapping = vim.fn.maparg("<leader>iv", mode, false, true)
  assert(mapping.expr == 1 and mapping.callback == refactoring.inline_var)
  assert(mapping.callback() == "g@l")
end

local bufnr = vim.api.nvim_get_current_buf()
vim.bo[bufnr].filetype = "javascript"
local lines = { "const value = 1;", "use(value);" }
local cleaned_lines = { "const value = 1;", "use(value);", "" }
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
vim.api.nvim_win_set_cursor(0, { 2, 5 })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>p", true, false, true), "mx", false)
assert(vim.wait(1000, function()
  return vim.api.nvim_buf_line_count(bufnr) > #lines
end))
assert(
  vim.tbl_contains(
    vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    "console.log('🐞 value', value)// __PRINT_VAR_END"
  ),
  vim.inspect(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
)

vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>P", true, false, true), "mx", false)
local has_cleaned = vim.wait(1000, function()
  return vim.deep_equal(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), cleaned_lines)
end)
assert(has_cleaned, vim.inspect(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)))
assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 2, 0 }))

vim.api.nvim_win_set_cursor(0, { 2, 4 })
vim.cmd.normal({ "viw", bang = true })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>p", true, false, true), "mx", false)
assert(vim.wait(1000, function()
  return vim.api.nvim_buf_line_count(bufnr) > #cleaned_lines
end))
assert(
  vim.tbl_contains(
    vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    "console.log('🐞 value', value)// __PRINT_VAR_END"
  )
)
vim.cmd.normal({ "ggVG", bang = true })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>P", true, false, true), "mx", false)
assert(vim.wait(1000, function()
  return vim.deep_equal(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), cleaned_lines)
end))

local filename = vim.fn.tempname() .. ".js"
vim.api.nvim_buf_set_name(bufnr, filename)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
vim.api.nvim_win_set_cursor(0, { 2, 4 })
vim.lsp.buf.definition = function(opts)
  opts.on_list({ items = { { filename = filename, lnum = 1, col = 7, end_lnum = 1, end_col = 12 } } })
end
vim.lsp.buf.references = function(_, opts)
  opts.on_list({ items = { { filename = filename, lnum = 2, col = 5, end_lnum = 2, end_col = 10 } } })
end
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>iv", true, false, true), "mx", false)
local has_inlined = vim.wait(1000, function()
  return vim.deep_equal(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), { "use((1));" })
end)
assert(has_inlined, vim.inspect(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)))

print("ok: refactoring mappings and debug prints")

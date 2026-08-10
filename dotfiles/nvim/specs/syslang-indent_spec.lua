require("lib")

vim.opt.runtimepath:append(vim.fn.getcwd() .. "/plugins/syslang")

local indent = require("syslang/indent")

local create_syslang_buffer = function(lines)
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].expandtab = true
  vim.bo[bufnr].shiftwidth = 2
  vim.bo[bufnr].tabstop = 2
  vim.bo[bufnr].filetype = "syslang"
  return bufnr
end

local get_lines = function(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local assert_valid_syslang = function(bufnr)
  local root = vim.treesitter.get_parser(bufnr, "syslang"):parse()[1]:root()
  assert(not root:has_error(), "outline edit produced invalid Syslang:\n" .. table.concat(get_lines(bufnr), "\n"))
end

local subtree_buffer = create_syslang_buffer({
  "* Parent",
  "  ** Child",
  "    [ ] Task",
  "      - Item",
})
vim.api.nvim_win_set_cursor(0, { 1, 2 })
indent.handle_indent()
assert(
  vim.deep_equal(get_lines(subtree_buffer), {
    "  ** Parent",
    "    *** Child",
    "      [ ] Task",
    "        - Item",
  }),
  "outline demotion did not preserve the complete subtree"
)
assert(vim.api.nvim_win_get_cursor(0)[2] == 5, "outline demotion did not keep the cursor on the same text")
assert(vim.api.nvim_get_current_line():sub(6, 6) == "P", "outline demotion moved the cursor off its text character")
assert(#get_lines(subtree_buffer) == 4, "outline demotion added a line at EOF")
assert(get_lines(subtree_buffer)[4] == "        - Item", "outline demotion changed the EOF shape")
assert_valid_syslang(subtree_buffer)

indent.handle_dedent()
assert(
  vim.deep_equal(get_lines(subtree_buffer), {
    "* Parent",
    "  ** Child",
    "    [ ] Task",
    "      - Item",
  }),
  "outline promotion did not restore the complete subtree"
)
assert(vim.api.nvim_win_get_cursor(0)[2] == 2, "outline promotion did not keep the cursor on the same text")
assert(vim.api.nvim_get_current_line():sub(3, 3) == "P", "outline promotion moved the cursor off its text character")
assert(#get_lines(subtree_buffer) == 4, "outline promotion added a line at EOF")
assert_valid_syslang(subtree_buffer)

local top_level_buffer = create_syslang_buffer({ "* Top" })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
indent.handle_dedent()
assert(vim.deep_equal(get_lines(top_level_buffer), { "* Top" }), "level 1 outline promoted above level 1")
assert(vim.api.nvim_win_get_cursor(0)[2] == 2, "level 1 promotion no-op moved the cursor")

local level_six_buffer = create_syslang_buffer({
  "* One",
  "  ** Two",
  "    *** Three",
  "      **** Four",
  "        ***** Five",
  "          ****** Six",
})
local level_six_lines = get_lines(level_six_buffer)
vim.api.nvim_win_set_cursor(0, { 6, 17 })
indent.handle_indent()
assert(vim.deep_equal(get_lines(level_six_buffer), level_six_lines), "level 6 outline demoted beyond level 6")
assert(vim.api.nvim_win_get_cursor(0)[2] == 17, "level 6 demotion no-op moved the cursor")

vim.api.nvim_win_set_cursor(0, { 5, 16 })
indent.handle_indent()
assert(
  vim.deep_equal(get_lines(level_six_buffer), level_six_lines),
  "outline demotion pushed a descendant beyond level 6"
)
assert_valid_syslang(level_six_buffer)

local tab_buffer = create_syslang_buffer({
  "* Parent",
  "\t** Child",
  "\t\t[ ] Task",
})
vim.bo[tab_buffer].expandtab = false
vim.api.nvim_win_set_cursor(0, { 2, 4 })
indent.handle_dedent()
assert(
  vim.deep_equal(get_lines(tab_buffer), { "* Parent", "* Child", "\t[ ] Task" }),
  "outline promotion did not preserve tab-indented children"
)
assert(vim.api.nvim_win_get_cursor(0)[2] == 2, "tab outline promotion did not keep the cursor on the same text")
assert_valid_syslang(tab_buffer)

indent.handle_indent()
assert(
  vim.deep_equal(get_lines(tab_buffer), { "* Parent", "\t** Child", "\t\t[ ] Task" }),
  "outline demotion did not restore tab-indented children"
)
assert(vim.api.nvim_win_get_cursor(0)[2] == 4, "tab outline demotion did not keep the cursor on the same text")
assert_valid_syslang(tab_buffer)

local fallback_buffer = create_syslang_buffer({ "plain text" })
vim.api.nvim_win_set_cursor(0, { 1, 3 })
indent.handle_indent()
assert(vim.deep_equal(get_lines(fallback_buffer), { "  plain text" }), "non-outline indent did not use normal >>")
indent.handle_dedent()
assert(vim.deep_equal(get_lines(fallback_buffer), { "plain text" }), "non-outline dedent did not use normal <<")

print("ok: Syslang structural outline indent and dedent")

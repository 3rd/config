require("lib")

vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/blink.lib")
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/blink.pairs")
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/site")
vim.opt.virtualedit = "onemore"

local pairing_plugin = nil
for _, plugin in ipairs(require("modules/workflow/text-editing").plugins) do
  if plugin[1] == "saghen/blink.pairs" then pairing_plugin = plugin end
end
assert(pairing_plugin, "text editing must configure brace pairing")
require("blink.pairs").setup(pairing_plugin.opts(nil, {}))

local function assert_insert_result(before, keys, expected)
  local cursor = assert(before:find("|", 1, true))
  local line = before:sub(1, cursor - 1) .. before:sub(cursor + 1)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
  vim.api.nvim_win_set_cursor(0, { 1, cursor - 1 })
  vim.api.nvim_feedkeys(vim.keycode("i" .. keys .. "<Esc>"), "xt", false)
  assert(
    vim.api.nvim_get_current_line() == expected,
    string.format("typing %s at %s must produce %s, got %s", keys, before, expected, vim.api.nvim_get_current_line())
  )
end

for _, case in ipairs({
  { "prefix |,", "prefix (," },
  { "|é", "(é" },
  { "prefix| word", "prefix() word" },
  { "|\tword", "()\tword" },
  { "prefix|", "prefix()" },
}) do
  assert_insert_result(case[1], "(", case[2])
end

local command_line = nil
vim.keymap.set("c", "<F5>", function()
  command_line = vim.fn.getcmdline()
  return ""
end, { expr = true })

for _, pair in ipairs({ "()", "[]", "{}" }) do
  local opening = pair:sub(1, 1)
  local closing = pair:sub(2, 2)
  assert_insert_result("|word", opening, opening .. "word")
  assert_insert_result("|", opening, pair)
  assert_insert_result("|", opening .. "x" .. closing, opening .. "x" .. closing)
  assert_insert_result("|", opening .. "<BS>", "")
  assert_insert_result("|", opening .. "<Space>", opening .. "  " .. closing)

  vim.api.nvim_feedkeys(vim.keycode(":word<Home>" .. opening .. "<F5><C-c>"), "xt", false)
  assert(command_line == pair .. "word", "command-line pairing must remain enabled before text for " .. pair)
end

vim.bo.filetype = "markdown"
assert_insert_result("- |", "[<Space>", "- [ ]")

for _, case in ipairs({
  { filetype = "", before = "|word", key = "'", expected = "'word" },
  { filetype = "", before = "|word", key = '"', expected = '"word' },
  { filetype = "", before = "|word", key = "`", expected = "`word" },
  { filetype = "markdown", before = "<|word", key = "!", expected = "<!word" },
  { filetype = "markdown", before = "``|word", key = "`", expected = "```word" },
  { filetype = "python", before = "''|word", key = "'", expected = "'''word" },
  { filetype = "python", before = '""|word', key = '"', expected = '"""word' },
  { filetype = "nix", before = "'|word", key = "'", expected = "''word" },
  { filetype = "rust", before = "r#|word", key = '"', expected = 'r#"word' },
  { filetype = "tex", before = "|word", key = "`", expected = "`word" },
  { filetype = "typst", before = "|word", key = "_", expected = "_word" },
  { filetype = "typst", before = "|word", key = "*", expected = "*word" },
}) do
  vim.bo.filetype = case.filetype
  assert_insert_result(case.before, case.key, case.expected)
end

vim.bo.filetype = ""
for _, quote in ipairs({ "'", "`" }) do
  assert_insert_result("|", quote .. "x" .. quote, quote .. "x" .. quote)
  assert_insert_result("|", quote .. "<BS>", "")
end
assert_insert_result("|", '"', '""')

vim.bo.filetype = "markdown"
assert_insert_result("<|", "!", "<!---->")
assert_insert_result("``|", "`", "``````")

vim.bo.filetype = "typst"
assert_insert_result("|", "_x_", "_x_")
assert_insert_result("|", "*x*", "*x*")

vim.bo.filetype = "typescript"
local parser = vim.treesitter.get_parser(0)
for _, case in ipairs({
  { before = "let value: Map", after = ";", expected = "let value: Map<;" },
  { before = "let value: Map", after = " ;", expected = "let value: Map<> ;" },
  { before = "let value = first ", after = " second", expected = "let value = first < second" },
}) do
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { case.before .. case.after })
  parser:parse(true)
  vim.api.nvim_win_set_cursor(0, { 1, #case.before })
  vim.api.nvim_feedkeys(vim.keycode("i<<Esc>"), "xt", false)
  assert(vim.api.nvim_get_current_line() == case.expected, "angle brackets must respect text and TypeScript syntax")
end

print("ok: all enabled auto-pairs respect following text and preserve paired editing and language rules")

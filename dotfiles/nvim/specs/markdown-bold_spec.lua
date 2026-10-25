require("lib")
vim.opt.runtimepath:prepend(vim.fn.stdpath("data") .. "/lazy/lush.nvim")

local bufnr = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Plain text", "**bold**", "***bold italic***" })
vim.bo[bufnr].filetype = "markdown"
vim.treesitter.start(bufnr, "markdown")
vim.treesitter.get_parser(bufnr):parse(true)

for _, colorscheme in ipairs({ "static", "dynamic" }) do
  vim.cmd.colorscheme(colorscheme)

  local captures = vim.treesitter.get_captures_at_pos(bufnr, 1, 3)
  local strong_capture = nil

  for _, capture in ipairs(captures) do
    if capture.capture == "markup.strong" then strong_capture = capture end
  end

  assert(strong_capture, "Markdown bold text must receive a strong capture")
  local highlight = vim.api.nvim_get_hl(0, {
    name = "@" .. strong_capture.capture .. "." .. strong_capture.lang,
    link = false,
  })
  assert(highlight.fg == 0xD184DB, colorscheme .. " Markdown bold must match the coding-agent purple")
  assert(highlight.bold, colorscheme .. " Markdown bold must retain its weight")
  assert(vim.api.nvim_get_hl(0, { name = "@markup.strong", link = false }).fg == nil)
end

vim.treesitter.stop(bufnr)
vim.cmd.syntax("enable")
vim.bo[bufnr].syntax = "markdown"

local bold_group = vim.fn.synIDattr(vim.fn.synID(2, 4, 1), "name")
assert(bold_group == "markdownBold", "Markdown syntax must recognize bold text without Tree-sitter")
local bold = vim.api.nvim_get_hl(0, { name = bold_group, link = false })
assert(bold.fg == 0xD184DB and bold.bold, "Markdown syntax bold must use purple and retain its weight")

local bold_italic_group = vim.fn.synIDattr(vim.fn.synID(3, 5, 1), "name")
assert(bold_italic_group == "markdownBoldItalic", "Markdown syntax must recognize combined emphasis")
local bold_italic = vim.api.nvim_get_hl(0, { name = bold_italic_group, link = false })
assert(
  bold_italic.fg == 0xD184DB and bold_italic.bold and bold_italic.italic,
  "Markdown combined emphasis must use purple and retain both styles"
)

print("ok: Markdown bold matches the coding-agent color in both themes and syntax highlighters")

require("lib")
lib.ts.register_prose_queries()
require("modules/language-support/languages/markdown").setup()

local bufnr = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "# Heading",
  "",
  "**visible** and [link](https://example.com)",
  "",
  "```lua",
  "local value = 1",
  "```",
  "",
  "**offscreen**",
})
vim.bo[bufnr].filetype = "markdown"
local parser = vim.treesitter.get_parser(bufnr, "markdown")
parser:parse(true)

require("lib/patches/treesitter-highlighter").setup()
vim.treesitter.start(bufnr, "markdown")
local highlighter = vim.treesitter.highlighter.active[bufnr]
assert(not highlighter._conceal_line, "disabled fence concealment still enabled per-line parsing")
highlighter:prepare_highlight_states(2, 6)
local languages = {}
local captures = {}

highlighter:for_each_highlight_state(function(state)
  local root = state.tstree:root()
  local first_row, _, last_row = root:range()
  assert(first_row <= 6 and last_row >= 2, "an offscreen tree reached the highlighter")
  local query = state.highlighter_query:query()
  languages[state.highlighter_query.lang] = true

  for id in query:iter_captures(root, bufnr, 2, 6) do
    captures[query.captures[id]] = true
  end
end)

assert(languages.markdown and languages.markdown_inline and languages.lua, "visible injections lost highlighting")
assert(captures["markup.strong"] and captures["markup.link.label"], "inline emphasis or links lost their captures")
assert(captures["keyword"] or captures["keyword.function"], "fenced code lost syntax highlighting")

vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "New paragraph", "" })
parser:parse({ 10, 11 })
highlighter:prepare_highlight_states(10, 10)
local has_moved_inline = false

highlighter:for_each_highlight_state(function(state)
  if state.highlighter_query.lang ~= "markdown_inline" then return end

  local row = state.tstree:root():range()
  assert(row == 10, "region filtering used stale positions after an edit")
  has_moved_inline = true
end)

assert(has_moved_inline, "the shifted inline tree was not highlighted")

print("ok: Markdown viewport highlighting preserves inline and fenced languages after edits")

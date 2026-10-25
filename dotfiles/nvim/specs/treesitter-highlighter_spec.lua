require("lib")
lib.ts.register_prose_queries()
require("lib/patches/treesitter-highlighter").setup()

local get_highlights = function(highlighter, start_row, end_row)
  highlighter:prepare_highlight_states(start_row, end_row)
  local captures = {}
  local languages = {}

  highlighter:for_each_highlight_state(function(state)
    local language = state.highlighter_query.lang
    languages[#languages + 1] = language
    captures[language] = captures[language] or {}
    local query = state.highlighter_query:query()

    for id, node in query:iter_captures(state.tstree:root(), highlighter.bufnr, start_row, end_row) do
      local capture = query.captures[id]
      captures[language][capture] = captures[language][capture] or {}
      table.insert(captures[language][capture], vim.treesitter.get_node_text(node, highlighter.bufnr))
    end
  end)

  return captures, languages
end

local bufnr = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '{ "number": 1, "enabled": true }' })
vim.treesitter.start(bufnr, "json")
vim.treesitter.get_parser(bufnr, "json"):parse(true)
local captures, languages = get_highlights(vim.treesitter.highlighter.active[bufnr], 0, 1)
assert(vim.deep_equal(languages, { "json" }), "a plain file lost its root syntax tree")
assert(captures.json.property and captures.json.number and captures.json.boolean, "plain JSON lost highlighting")

vim.treesitter.stop(bufnr)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "<html>",
  "<style>",
  "body { color: red; }",
  "</style>",
  "<script>",
  "const template = html`<strong>nested</strong>`;",
  "</script>",
  "</html>",
  "",
  "<script>",
  "const offscreen = 2;",
  "</script>",
})
vim.treesitter.start(bufnr, "html")
local parser = vim.treesitter.get_parser(bufnr, "html")
parser:parse(true)
local highlighter = vim.treesitter.highlighter.active[bufnr]
captures, languages = get_highlights(highlighter, 0, 7)
assert(languages[1] == "html", "the parent tree must be highlighted before injected languages")
assert(captures.javascript.keyword, "embedded JavaScript lost highlighting")
assert(vim.tbl_contains(captures.css.property, "color"), "embedded CSS lost highlighting")
assert(vim.tbl_contains(captures.html.tag, "strong"), "nested HTML inside JavaScript lost highlighting")
local javascript_index
local nested_html_index

for index, language in ipairs(languages) do
  if language == "javascript" then javascript_index = index end
  if language == "html" and index > 1 then nested_html_index = index end
end

assert(javascript_index < nested_html_index, "a nested injection was highlighted before its parent")

vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "", "" })
parser:parse({ 11, 14 })
captures, languages = get_highlights(highlighter, 11, 14)
assert(vim.deep_equal(languages, { "html", "javascript" }), "offscreen injections reached the redraw state")
assert(vim.tbl_contains(captures.javascript.variable, "offscreen"), "an edit left stale injection positions")

vim.treesitter.stop(bufnr)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "<div>",
  "first region",
  "</div>",
  "",
  "Text between regions.",
  "",
  "**Markdown gap**",
  "",
  "More text between regions.",
  "",
  "<div>",
  "second region",
  "</div>",
})
vim.treesitter.start(bufnr, "markdown")
vim.treesitter.get_parser(bufnr, "markdown"):parse(true)
highlighter = vim.treesitter.highlighter.active[bufnr]
captures = get_highlights(highlighter, 10, 13)
assert(vim.tbl_contains(captures.html.tag, "div"), "the later region of a combined injection lost highlighting")
captures = get_highlights(highlighter, 6, 7)
assert(not captures.html, "a combined injection was materialized inside a gap between its regions")
assert(captures.markdown_inline["markup.strong"], "the gap between injected regions lost its own highlighting")

local offscreen_tree = {
  root = function()
    error("offscreen syntax tree was materialized during redraw")
  end,
}
local offscreen_parser = {
  lang = function()
    return "html"
  end,
  included_regions = function()
    return { { { 100, 0, 1000, 101, 0, 1020 } } }
  end,
  trees = function()
    return { offscreen_tree }
  end,
  children = function()
    return {}
  end,
  for_each_tree = function(self, callback)
    callback(offscreen_tree, self)
  end,
}
local offscreen_highlighter = { tree = offscreen_parser }
vim.treesitter.highlighter.prepare_highlight_states(offscreen_highlighter, 0, 10)
assert(vim.tbl_isempty(offscreen_highlighter._highlight_states), "offscreen regions reached the redraw state")

print("ok: viewport highlighting preserves plain files, multiple and nested injections, and edited regions")

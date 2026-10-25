require("lib")

vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/headlines.nvim")
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/lush.nvim")
require("modules/ui/headlines").plugins[1].config()

local namespace = vim.api.nvim_get_namespaces().prose_render
local bufnr = vim.api.nvim_get_current_buf()
local render_markdown = function(lines)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "markdown"
  vim.api.nvim_exec_autocmds("BufEnter", { buffer = bufnr })
end

local find_highlights = function(group)
  local matches = {}

  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })) do
    if mark[4].hl_group == group then matches[#matches + 1] = mark end
  end

  return matches
end

local get_highlight = function(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false })
end

for _, colorscheme in ipairs({ "static", "dynamic" }) do
  vim.cmd.colorscheme(colorscheme)

  for level = 1, 6 do
    local syslang = get_highlight("@slang.heading_" .. level .. ".text")
    local markdown = get_highlight("@markup.heading." .. level .. ".markdown")
    assert(vim.deep_equal(syslang, markdown), colorscheme .. " heading styles differ at level " .. level)
    assert(syslang.bold, "headings must retain Syslang's bold weight")
  end

  assert(vim.deep_equal(get_highlight("MarkdownTitle"), get_highlight("@slang.document.title")))
  assert(vim.deep_equal(get_highlight("MarkdownExternalLink"), get_highlight("@slang.external_link")))
  assert(vim.deep_equal(get_highlight("MarkdownImage"), get_highlight("@slang.image")))
  assert(vim.deep_equal(get_highlight("MarkdownCodeFence"), get_highlight("@slang.code_block_start")))
  assert(vim.deep_equal(get_highlight("@markup.raw.block.markdown"), get_highlight("@slang.code_block_content")))
  assert(vim.deep_equal(get_highlight("@markup.list.numbered.markdown"), get_highlight("@slang.number")))
  assert(vim.deep_equal(get_highlight("@slang.label_line.syslang"), get_highlight("markdownBold")))
  assert(get_highlight("@slang.comment").italic, "Syslang comments must be italic")
end

render_markdown({ "> # Quoted heading", "", "# Document", "", "# Heading", "", "## Subheading", "" })
local titles = find_highlights("MarkdownTitle")
assert(#titles == 1 and titles[1][2] == 2, "the first top-level H1 must be the only document title")
local headings = find_highlights("SyslangHeadline1")
assert(#headings == 2 and headings[2][2] == 4, "later H1s must retain heading bands")
local title_gap = vim.b[bufnr].syslang_headline_gutter_rows[4]
assert(title_gap and title_gap.char == "▄", "the title must not suppress the next heading's upper padding")

vim.api.nvim_buf_set_lines(bufnr, 2, 3, false, { "Plain text" })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = bufnr })
assert(
  vim.wait(1000, function()
    return vim.b[bufnr].prose_render_changedtick == vim.api.nvim_buf_get_changedtick(bufnr)
  end),
  "edited Markdown did not render"
)
titles = find_highlights("MarkdownTitle")
assert(#titles == 1 and titles[1][2] == 4, "removing the first H1 must promote the next title")

render_markdown({ "Document", "========", "", "Heading", "=======", "", "Subheading", "----------", "" })
titles = find_highlights("MarkdownTitle")
headings = find_highlights("SyslangHeadline1")
assert(#titles == 1 and titles[1][2] == 0 and titles[1][4].end_row == 2)
assert(#headings == 1 and headings[1][2] == 3 and headings[1][4].end_row == 5)
assert(#find_highlights("SyslangHeadline2") == 1, "setext H2 must get its own heading band")

for _, metadata in ipairs({
  { delimiter = "---", field = "owner: Robin", language = "yaml" },
  { delimiter = "+++", field = 'owner = "Robin"', language = "toml" },
}) do
  render_markdown({
    metadata.delimiter,
    metadata.field,
    metadata.delimiter,
    "",
    "```" .. metadata.language,
    metadata.field,
    "```",
    "",
    "    plain code",
    "",
  })
  local keys = find_highlights("MarkdownMetadataKey")
  local values = find_highlights("MarkdownMetadataValue")
  assert(#keys == 1 and keys[1][2] == 1, metadata.language .. " metadata keys escaped frontmatter")
  assert(#values > 0, metadata.language .. " frontmatter values have no highlights")

  for _, value in ipairs(values) do
    assert(value[2] == 1, metadata.language .. " metadata values escaped frontmatter")
  end

  local blocks = find_highlights("CodeBlock")
  assert(#blocks == 2, "both fenced and indented code must have backgrounds")
  assert(blocks[1][2] == 5 and blocks[1][4].end_row == 6, "code background must exclude fences")
  assert(blocks[2][2] == 8 and blocks[2][4].end_row == 10, "indented code background has the wrong range")
end

render_markdown({
  "[Full][WEB] [Collapsed][] [Shortcut] [Local][file]",
  "",
  "[web]: https://example.com",
  "[collapsed]: https://example.com",
  "[shortcut]: https://example.com",
  "[file]: ./garden.md",
})
local links = find_highlights("MarkdownExternalLink")
assert(#links == 3, "external reference labels must be styled without changing local links")

for _, link in ipairs(links) do
  assert(link[2] == 0 and link[4].end_col < 37, "external reference styling escaped its label")
end

vim.api.nvim_buf_set_lines(bufnr, 2, 3, false, { "[web]: ./local.md" })
vim.api.nvim_exec_autocmds("InsertLeave", { buffer = bufnr })
assert(#find_highlights("MarkdownExternalLink") == 2, "editing a reference destination left a stale external style")

for _, language in ipairs({ "syslang", "markdown" }) do
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "![Garden](garden.png)", "" })
  local parser = vim.treesitter.get_parser(bufnr, language)
  parser:parse(true)
  local image_ranges = {}
  parser:for_each_tree(function(tree, language_tree)
    local query = vim.treesitter.query.get(language_tree:lang(), "highlights")
    if not query then return end

    for id, node, metadata in query:iter_captures(tree:root(), bufnr, 0, 1) do
      if query.captures[id] == "slang.image" or query.captures[id] == "markup.image" then
        local capture_metadata = metadata[id] or {}
        local conceal = capture_metadata.conceal or metadata.conceal
        if conceal then
          local range = vim.treesitter.get_range(node, bufnr, capture_metadata)
          image_ranges[range[2]] = { last_column = range[5], conceal = conceal }
        end
      end
    end
  end)
  assert(image_ranges[0].conceal == require("config/prose").image and image_ranges[0].last_column == 1)
  assert(image_ranges[1].conceal == " " and image_ranges[1].last_column == 2, language .. " image has no gap")
end

render_markdown({ "# Document", "", "## Heading", "" })
vim.cmd.vsplit()
vim.api.nvim_win_set_width(0, 20)
vim.api.nvim_exec_autocmds("WinResized", { pattern = tostring(vim.api.nvim_get_current_win()) })
local width = 0

for _, window in ipairs(vim.fn.win_findbuf(bufnr)) do
  width = math.max(width, vim.api.nvim_win_get_width(window))
end

local padding = vim.api.nvim_buf_get_extmarks(bufnr, namespace, { 3, 0 }, { 3, -1 }, { details = true })
assert(#padding == 1 and vim.fn.strdisplaywidth(padding[1][4].virt_text[1][1]) == width)
vim.cmd.close()
vim.bo[bufnr].filetype = "text"
assert(#vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {}) == 0, "prose styles survived a filetype change")

bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(bufnr)
local lines = { "# Document", "", "## Visible heading", "", "---", "" }

for index = 1, 80 do
  vim.list_extend(lines, { "Paragraph " .. index .. " with **bold** text.", "" })
end

vim.list_extend(lines, { "# Later heading", "", "[Remote][web]", "", "[web]: https://example.com", "" })
render_markdown(lines)
local parser = vim.treesitter.get_parser(bufnr, "markdown")
assert(
  parser:children().markdown_inline:tree_for_range({ 100, 0, 100, 5 }) == nil,
  "prose rendering parsed offscreen inline text"
)
assert(#find_highlights("SyslangHeadline1") == 0, "offscreen heading bands were eagerly rendered")
local has_dash = false

for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, namespace, { 4, 0 }, { 4, -1 }, { details = true })) do
  local text = mark[4].virt_text
  if text and text[1][2] == "Dash" then has_dash = true end
end

assert(has_dash, "Markdown horizontal rules lost their decoration")

vim.api.nvim_win_set_cursor(0, { 167, 0 })
vim.cmd("normal! zt")
vim.api.nvim_exec_autocmds("WinScrolled", { pattern = tostring(vim.api.nvim_get_current_win()) })
assert(#find_highlights("MarkdownTitle") == 0, "scrolling promoted a later H1 to the document title")
assert(#find_highlights("SyslangHeadline1") == 1, "scrolling did not render the newly visible heading")
assert(#find_highlights("MarkdownExternalLink") == 1, "scrolling lost external reference styling")

vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "Plain text" })
vim.api.nvim_exec_autocmds("InsertLeave", { buffer = bufnr })
titles = find_highlights("MarkdownTitle")
assert(#titles == 1 and titles[1][2] == 166, "editing an offscreen title did not promote the visible H1")

local marks_before_resize = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
local other_buffer = vim.api.nvim_create_buf(false, true)
local other_window = vim.api.nvim_open_win(other_buffer, false, {
  relative = "editor",
  row = 0,
  col = 0,
  width = 10,
  height = 2,
})
vim.api.nvim_exec_autocmds("WinResized", { pattern = tostring(other_window) })
assert(
  vim.deep_equal(marks_before_resize, vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })),
  "resizing an unrelated window rebuilt Markdown decorations"
)
vim.api.nvim_win_close(other_window, true)

print("ok: shared prose styles, Markdown titles, metadata, code blocks, and image spacing")

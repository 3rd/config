require("lib")

local annotations = require("modules/workflow/annotations")
annotations.setup()
local action = annotations.actions[1]
local burn = action[3]
local visible = action[4]
assert(action[1] == "n" and action[2] == "Annotations: Burn annotations into current file")

local create_buffer = function(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

local add_annotation = function(row, comment, selection)
  vim.api.nvim_win_set_cursor(0, { row, 0 })
  if selection then vim.api.nvim_feedkeys(selection, "nx", false) end
  local source = vim.api.nvim_get_current_buf()
  annotations.mappings[1][3]()
  assert(
    vim.wait(1000, function()
      return vim.api.nvim_get_current_buf() ~= source
    end),
    "annotation prompt did not complete"
  )
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(comment, "\n", { plain = true }))
  vim.cmd.write()
end

local other = create_buffer({ "other file" })
assert(not visible(), "empty buffers must hide the command")
add_annotation(1, "Keep this note virtual")

local current = create_buffer({ "heading", "first", "middle", "last", "tail" })
assert(not visible(), "annotations in another buffer must not show the command")
add_annotation(4, "Replace this range\nPreserve its behavior", "Vj")
add_annotation(2, "Simplify this expression")
assert(visible(), "current-buffer annotations must show the command")
vim.api.nvim_buf_set_lines(current, 0, 0, false, { "inserted before annotation" })
local original = vim.api.nvim_buf_get_lines(current, 0, -1, false)
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<C-G>u<Esc>", true, false, true), "nx", false)

burn()

local expected = {
  "inserted before annotation",
  "heading",
  "first",
  "<annotation>",
  "<original>",
  "first",
  "</original>",
  "<comment>",
  "Simplify this expression",
  "</comment>",
  "</annotation>",
  "middle",
  "last",
  "tail",
  "<annotation>",
  "<original>",
  "last",
  "tail",
  "</original>",
  "<comment>",
  "Replace this range",
  "Preserve its behavior",
  "</comment>",
  "</annotation>",
}
local actual = vim.api.nvim_buf_get_lines(current, 0, -1, false)
assert(vim.deep_equal(actual, expected), vim.inspect(actual))
assert(not visible(), "burned annotations must no longer show the command")
assert(annotations.exports.count() == 1, "only the current buffer's annotations should be consumed")
local render_namespace = vim.api.nvim_get_namespaces()["workflow-annotations-render"]
assert(#vim.api.nvim_buf_get_extmarks(current, render_namespace, 0, -1, {}) == 0)
assert(#vim.api.nvim_buf_get_extmarks(other, render_namespace, 0, -1, {}) == 2)
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(other, 0, -1, false), { "other file" }))
burn()
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(current, 0, -1, false), expected))
vim.cmd("undo")
assert(
  vim.deep_equal(vim.api.nvim_buf_get_lines(current, 0, -1, false), original),
  "one undo must remove all burned text"
)

vim.api.nvim_set_current_buf(other)
vim.bo[other].modifiable = false
local ok = pcall(burn)
assert(not ok, "burning into a nonmodifiable buffer must fail")
assert(visible() and annotations.exports.count() == 1, "a failed insertion must preserve the annotation")

local partial = create_buffer({ "left abc right" })
add_annotation(1, "Rename these three characters", "wvll")
burn()
local partial_expected = {
  "left abc right",
  "<annotation>",
  "<original>",
  "abc",
  "</original>",
  "<comment>",
  "Rename these three characters",
  "</comment>",
  "</annotation>",
}
local partial_actual = vim.api.nvim_buf_get_lines(partial, 0, -1, false)
assert(vim.deep_equal(partial_actual, partial_expected), vim.inspect(partial_actual))

local selection_cases = {
  { lines = { "left aé界 right" }, keys = "wvll", code = "aé界" },
  { lines = { "left abc right" }, keys = "wllvhh", code = "abc" },
  { lines = { "left abc right" }, keys = "wvlll", code = "abc", selection = "exclusive" },
  { lines = { "left abc", "def right" }, keys = "wvj0ll", code = "abc\ndef" },
  { lines = { "whole line", "next line" }, keys = "Vj", code = "whole line\nnext line" },
  { lines = { "left abc right" }, keys = "w\22ll", code = "abc" },
  { lines = { "left abc right", "left def right" }, keys = "w\22jll", code = "abc\ndef" },
  { lines = { "left aé界 right" }, keys = "w\22ll", code = "aé界" },
}
local exported
local setreg = vim.fn.setreg
vim.fn.setreg = function(_, content)
  exported = content
end
for _, case in ipairs(selection_cases) do
  local bufnr = create_buffer(case.lines)
  vim.o.selection = case.selection or "inclusive"
  add_annotation(1, "Selected text", case.keys)
  local highlighted = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, render_namespace, 0, -1, { details = true })) do
    local details = mark[4]
    if details.hl_group == "AnnotationsRange" then
      vim.list_extend(
        highlighted,
        vim.api.nvim_buf_get_text(bufnr, mark[2], mark[3], details.end_row, details.end_col, {})
      )
    end
  end
  assert(table.concat(highlighted, "\n") == case.code, "source highlights must cover exactly the annotated text")
  annotations.mappings[2][3]()
  assert(exported:find("```\n" .. case.code .. "\n```", 1, true), exported)
  burn()
  local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  assert(content:find("<original>\n" .. case.code .. "\n</original>\n<comment>", 1, true), content)
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(bufnr, 0, #case.lines, false), case.lines), content)
end
vim.fn.setreg = setreg
vim.o.selection = "inclusive"

local block_buffer = create_buffer({ "left abc xyz", "left def uvw" })
local count_before_blocks = annotations.exports.count()
add_annotation(1, "Left block", "w\22jll")
add_annotation(1, "Right block", "ww\22jll")
assert(annotations.exports.count() == count_before_blocks + 2, "disjoint blocks must remain separate annotations")
vim.api.nvim_buf_set_lines(block_buffer, 1, 1, false, { "inserted between block rows" })
add_annotation(2, "Inserted line")
assert(annotations.exports.count() == count_before_blocks + 3, "inserted lines must not become part of a block")
burn()
local block_content = table.concat(vim.api.nvim_buf_get_lines(block_buffer, 0, -1, false), "\n")
assert(block_content:find("<original>\nabc\ndef\n</original>\n<comment>\nLeft block", 1, true), block_content)
assert(block_content:find("<original>\nxyz\nuvw\n</original>\n<comment>\nRight block", 1, true), block_content)
local range_namespace = vim.api.nvim_get_namespaces()["workflow-annotations-range"]
assert(
  #vim.api.nvim_buf_get_extmarks(block_buffer, range_namespace, 0, -1, {}) == 0,
  "burning must remove all block marks"
)

local restored_block = create_buffer({ "left abc", "left def" })
add_annotation(1, "Restorable block", "w\22jll")
local count_before_clear = annotations.exports.count()
annotations.mappings[3][3]()
assert(annotations.exports.count() == 0, "clear must hide all annotations")
assert(#vim.api.nvim_buf_get_extmarks(restored_block, render_namespace, 0, -1, {}) == 0)
annotations.mappings[3][3]()
assert(annotations.exports.count() == count_before_clear, "restore must recover block annotations")
assert(#vim.api.nvim_buf_get_extmarks(restored_block, render_namespace, 0, -1, {}) == 3)
add_annotation(1, "Only the first row", "wvll")
assert(annotations.exports.count() == count_before_clear, "editing a block must not create another annotation")
assert(
  #vim.api.nvim_buf_get_extmarks(restored_block, range_namespace, 0, -1, {}) == 1,
  "resizing must remove old block marks"
)
burn()
local restored_content = table.concat(vim.api.nvim_buf_get_lines(restored_block, 0, -1, false), "\n")
assert(restored_content:find("<original>\nabc\n</original>\n<comment>\nOnly the first row", 1, true), restored_content)

for _, case in ipairs({
  { line = "    local value = 1", width = 4 },
  { line = "\tlocal value = 1", width = 8 },
  { line = "left abc right", selection = "wvll", width = 5 },
  { line = "界 abc right", selection = "wvll", width = 3 },
}) do
  local bufnr = create_buffer({ case.line })
  vim.bo.tabstop = 8
  add_annotation(1, "Aligned note\nSecond line", case.selection)
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, render_namespace, 0, -1, { details = true })) do
    if mark[4].virt_lines then
      for _, line in ipairs(mark[4].virt_lines) do
        assert(#line[1][1]:match("^ *") == case.width, "every annotation line must align with its source")
      end
    end
  end
end

local draft_source = create_buffer({ "first", "anchored", "last" })
local source_window = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_cursor(0, { 2, 0 })
local count_before_draft = annotations.exports.count()
annotations.mappings[1][3]()
assert(vim.wait(1000, function()
  return vim.api.nvim_get_current_buf() ~= draft_source
end))
local editor = vim.api.nvim_win_get_config(0)
assert(vim.b.completion == false, "annotation editor must disable completion that captures arrow keys")
assert(editor.relative == "win" and editor.win == source_window and editor.bufpos[1] == 1)
assert(not vim.wo.number and vim.wo.winhighlight:find("Normal:AnnotationsEditor", 1, true))
local editor_highlight = vim.api.nvim_get_hl(0, { name = "AnnotationsEditor" })
assert(editor_highlight.bg == tonumber("2E291F", 16) and not editor_highlight.bold and not editor_highlight.underline)
vim.api.nvim_buf_set_lines(draft_source, 0, 0, false, { "inserted" })
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "First paragraph", "", "Second paragraph" })
vim.cmd.write()
assert(annotations.exports.count() == count_before_draft + 1)
burn()
assert(
  vim.deep_equal(vim.api.nvim_buf_get_lines(draft_source, 0, -1, false), {
    "inserted",
    "first",
    "anchored",
    "<annotation>",
    "<original>",
    "anchored",
    "</original>",
    "<comment>",
    "First paragraph",
    "",
    "Second paragraph",
    "</comment>",
    "</annotation>",
    "last",
  }),
  "submitting a multiline draft must follow its source through edits"
)

annotations.mappings[1][3]()
assert(vim.wait(1000, function()
  return vim.api.nvim_get_current_buf() ~= draft_source
end))
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Do not submit this" })
vim.cmd("quit")
assert(annotations.exports.count() == count_before_draft, "closing a draft must cancel it")
assert(#vim.api.nvim_buf_get_extmarks(draft_source, range_namespace, 0, -1, {}) == 0)

add_annotation(1, "Original note\nKept")
annotations.mappings[1][3]()
assert(vim.wait(1000, function()
  return vim.api.nvim_get_current_buf() ~= draft_source
end))
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "Original note", "Kept" }))
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Canceled replacement" })
vim.cmd("quit")
burn()
local after_cancel = table.concat(vim.api.nvim_buf_get_lines(draft_source, 0, -1, false), "\n")
assert(after_cancel:find("Original note\nKept", 1, true) and not after_cancel:find("Canceled replacement", 1, true))

local bottom_source = create_buffer(vim.fn["repeat"]({ "    source line" }, 100))
vim.api.nvim_win_set_cursor(0, { 100, 4 })
vim.cmd("normal! zb")
vim.cmd.redraw()
annotations.mappings[1][3]()
assert(vim.wait(1000, function()
  return vim.api.nvim_get_current_buf() ~= bottom_source
end))
assert(vim.api.nvim_win_get_config(0).anchor == "SW", "annotation editor must open above text near the bottom")
vim.cmd("quit")

print("ok: annotations preserve selections, support multiline drafts, track source edits, and cancel without changes")

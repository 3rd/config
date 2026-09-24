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

local open_annotation = function(row, selection)
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
end

local save_annotation = function(comment)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(comment, "\n", { plain = true }))
  vim.cmd.write()
end

local add_annotation = function(row, comment, selection)
  open_annotation(row, selection)
  save_annotation(comment)
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
open_annotation(1, "8l")
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "" }), "block gaps must not select a note")
vim.cmd.quit()
open_annotation(2, "w")
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "Left block" }))
vim.cmd.quit()
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
assert(annotations.exports.count() == count_before_clear + 1, "a nested selection must create a separate annotation")
assert(
  #vim.api.nvim_buf_get_extmarks(restored_block, range_namespace, 0, -1, {}) == 3,
  "a nested annotation must preserve every block segment"
)
burn()
local restored_content = table.concat(vim.api.nvim_buf_get_lines(restored_block, 0, -1, false), "\n")
assert(restored_content:find("<original>\nabc\n</original>\n<comment>\nOnly the first row", 1, true), restored_content)
assert(
  restored_content:find("<original>\nabc\ndef\n</original>\n<comment>\nRestorable block", 1, true),
  restored_content
)

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

local rendered_text = function(bufnr)
  local lines = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, render_namespace, 0, -1, { details = true })) do
    for _, line in ipairs(mark[4].virt_lines or {}) do
      local chunks = {}
      for _, chunk in ipairs(line) do
        chunks[#chunks + 1] = chunk[1]
      end
      lines[#lines + 1] = table.concat(chunks)
    end
  end
  return table.concat(lines, "\n")
end

local same_line = create_buffer({ "abcdef ghij klmn" })
local count_before_same_line = annotations.exports.count()
add_annotation(1, "Right note", "wwvlll")
add_annotation(1, "Left note", "vll")
add_annotation(1, "Adjacent note", "3lvll")
assert(annotations.exports.count() == count_before_same_line + 3, "same-line ranges must remain independent")
open_annotation(1, "vll")
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "Left note" }))
save_annotation("Edited left")
open_annotation(1, "ww")
assert(
  vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "Right note" }),
  "the cursor must select the right note"
)
assert(vim.api.nvim_win_get_config(0).bufpos[2] == 12, "the editor must anchor to the selected range")
save_annotation("Edited right")
open_annotation(1, "3l")
assert(
  vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "Adjacent note" }),
  "shared boundaries belong to the next range"
)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Canceled adjacent edit" })
vim.cmd.quit()
assert(annotations.exports.count() == count_before_same_line + 3, "editing must not duplicate a range")

local highlighted_ranges = {}
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(same_line, render_namespace, 0, -1, { details = true })) do
  local details = mark[4]
  if details.hl_group == "AnnotationsRange" then
    highlighted_ranges[#highlighted_ranges + 1] =
      table.concat(vim.api.nvim_buf_get_text(same_line, mark[2], mark[3], details.end_row, details.end_col, {}), "\n")
  end
end
assert(vim.deep_equal(highlighted_ranges, { "abc", "def", "klmn" }), vim.inspect(highlighted_ranges))
local expected_render =
  "│  │        ╰─ 󰙏 Edited right\n│  ╰─ 󰙏 Adjacent note\n╰─ 󰙏 Edited left"
assert(rendered_text(same_line) == expected_render, rendered_text(same_line))
annotations.mappings[3][3]()
annotations.mappings[3][3]()
assert(annotations.exports.count() == count_before_same_line + 3)
assert(rendered_text(same_line) == expected_render, "restoring must preserve same-line note order")

vim.fn.setreg = function(_, content)
  exported = content
end
annotations.mappings[2][3]()
vim.fn.setreg = setreg
local left_export = assert(exported:find("```\nabc\n```\n\nComment:\nEdited left", 1, true), exported)
local adjacent_export = assert(exported:find("```\ndef\n```\n\nComment:\nAdjacent note", 1, true), exported)
local right_export = assert(exported:find("```\nklmn\n```\n\nComment:\nEdited right", 1, true), exported)
assert(left_export < adjacent_export and adjacent_export < right_export, "export must follow range order")
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<C-G>u<Esc>", true, false, true), "nx", false)
burn()
local same_line_burned = table.concat(vim.api.nvim_buf_get_lines(same_line, 0, -1, false), "\n")
local left_burn = assert(same_line_burned:find("<original>\nabc\n</original>\n<comment>\nEdited left", 1, true))
local adjacent_burn = assert(same_line_burned:find("<original>\ndef\n</original>\n<comment>\nAdjacent note", 1, true))
local right_burn = assert(same_line_burned:find("<original>\nklmn\n</original>\n<comment>\nEdited right", 1, true))
assert(left_burn < adjacent_burn and adjacent_burn < right_burn, "burn must follow range order")
assert(annotations.exports.count() == count_before_same_line)
vim.cmd.undo()
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(same_line, 0, -1, false), { "abcdef ghij klmn" }))

local connected_notes = create_buffer({ "left right" })
add_annotation(1, "A long note that would cross the other guide", "ve")
add_annotation(1, "First line\nSecond line", "wve")
assert(
  rendered_text(connected_notes)
    == "│    ├─ 󰙏 note\n│    │  First line\n│    ╰  Second line\n╰─ 󰙏 A long note that would cross the other guide",
  "guides must connect through multiline notes without crossing another comment"
)

local overlapping = create_buffer({ "abcdef gap" })
local count_before_overlapping = annotations.exports.count()
add_annotation(1, "Outer note", "vlll")
add_annotation(1, "Nested note", "lvll")
add_annotation(1, "Crossing note", "llvlll")
assert(annotations.exports.count() == count_before_overlapping + 3, "nested and overlapping selections must coexist")
open_annotation(1, "w")
assert(
  vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "" }),
  "an unannotated position must start a new note"
)
save_annotation("Whole line note")
open_annotation(1, "lvll")
assert(
  vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "Nested note" }),
  "exact matches must bypass overlaps"
)
vim.cmd.quit()

local select = vim.ui.select
local choices
vim.ui.select = function(items, opts, on_choice)
  choices = vim.tbl_map(opts.format_item, items)
  on_choice(items[3])
end
open_annotation(1, "ll")
assert(
  vim.deep_equal(choices, {
    "1:1–1:4 — Outer note",
    "1:1–1:10 — Whole line note",
    "1:2–1:4 — Nested note",
    "1:3–1:6 — Crossing note",
  }),
  vim.inspect(choices)
)
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "Nested note" }))
save_annotation("Edited nested")
assert(annotations.exports.count() == count_before_overlapping + 4)

local flush_scheduled = function()
  local completed = false
  vim.schedule(function()
    completed = true
  end)
  assert(vim.wait(1000, function()
    return completed
  end))
end

local before_canceling_picker = rendered_text(overlapping)
vim.ui.select = function(_, _, on_choice)
  on_choice(nil)
end
vim.api.nvim_win_set_cursor(0, { 1, 2 })
annotations.mappings[1][3]()
flush_scheduled()
assert(vim.api.nvim_get_current_buf() == overlapping, "canceling the chooser must not open an editor")
assert(rendered_text(overlapping) == before_canceling_picker)
assert(
  #vim.api.nvim_buf_get_extmarks(overlapping, range_namespace, 0, -1, {}) == 4,
  "canceling must not leak draft marks"
)

vim.ui.select = function(items, _, on_choice)
  on_choice(items[3])
end
open_annotation(1, "ll")
save_annotation("")
assert(
  annotations.exports.count() == count_before_overlapping + 3,
  "empty submission must delete only the chosen note"
)
assert(rendered_text(overlapping):find("Outer note", 1, true))
assert(rendered_text(overlapping):find("Crossing note", 1, true))
assert(not rendered_text(overlapping):find("Edited nested", 1, true))

local pending_items
local pending_choice
local defer_choice = function(items, _, on_choice)
  pending_items = items
  pending_choice = on_choice
end
vim.ui.select = defer_choice
vim.api.nvim_win_set_cursor(0, { 1, 2 })
annotations.mappings[1][3]()
vim.api.nvim_buf_set_lines(overlapping, 0, 0, false, { "inserted before choosing" })
pending_choice(pending_items[3])
assert(vim.wait(1000, function()
  return vim.api.nvim_get_current_buf() ~= overlapping
end))
assert(vim.api.nvim_win_get_config(0).bufpos[1] == 1, "the chooser must resolve the live range after source movement")
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "Crossing note" }))
vim.api.nvim_buf_set_text(overlapping, 1, 2, 1, 6, { "WXYZ" })
save_annotation("Moved crossing")
vim.fn.setreg = function(_, content)
  exported = content
end
annotations.mappings[2][3]()
vim.fn.setreg = setreg
assert(
  exported:find("```\ncdef\n```\n\nComment:\nMoved crossing", 1, true),
  "editing must retain the original snapshot"
)

local notify = vim.notify
local failure
vim.notify = function(message)
  failure = message
end
local count_before_invalidating = annotations.exports.count()
vim.api.nvim_win_set_cursor(0, { 2, 2 })
annotations.mappings[1][3]()
annotations.mappings[3][3]()
failure = nil
pending_choice(pending_items[3])
flush_scheduled()
assert(failure == "Annotation source is no longer available", failure)
assert(vim.api.nvim_get_current_buf() == overlapping and annotations.exports.count() == 0)
assert(
  #vim.api.nvim_buf_get_extmarks(overlapping, range_namespace, 0, -1, {}) == 3,
  "a stale choice must not add draft marks"
)
annotations.mappings[3][3]()
assert(annotations.exports.count() == count_before_invalidating)

vim.ui.select = function(items, _, on_choice)
  on_choice(items[3])
end
open_annotation(2, "ll")
annotations.mappings[3][3]()
failure = nil
save_annotation("Do not resurrect this note")
assert(failure == "Annotation source is no longer available", failure)
assert(annotations.exports.count() == 0, "submitting a removed note must not recreate it")
vim.cmd.quit()
annotations.mappings[3][3]()
assert(annotations.exports.count() == count_before_invalidating)
assert(rendered_text(overlapping):find("Moved crossing", 1, true))
assert(not rendered_text(overlapping):find("Do not resurrect this note", 1, true))

vim.ui.select = defer_choice
vim.api.nvim_win_set_cursor(0, { 2, 2 })
annotations.mappings[1][3]()
vim.api.nvim_buf_delete(overlapping, { force = true })
local after_source_delete = vim.api.nvim_get_current_buf()
failure = nil
pending_choice(pending_items[3])
flush_scheduled()
assert(failure == "Annotation source is no longer available", failure)
assert(vim.api.nvim_get_current_buf() == after_source_delete, "a stale choice must not target another buffer")
assert(annotations.exports.count() == count_before_invalidating - 3)
vim.ui.select = select

local abandoned_draft = create_buffer({ "pending draft" })
failure = nil
annotations.mappings[1][3]()
vim.api.nvim_set_current_buf(same_line)
flush_scheduled()
assert(failure == "Annotation source is no longer available", failure)
assert(vim.api.nvim_get_current_buf() == same_line)
assert(
  #vim.api.nvim_buf_get_extmarks(abandoned_draft, range_namespace, 0, -1, {}) == 0,
  "an unopened draft must be cleaned up"
)
vim.notify = notify

local blank = create_buffer({ "" })
local count_before_blank = annotations.exports.count()
add_annotation(1, "Blank note")
open_annotation(1)
assert(
  vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "Blank note" }),
  "empty ranges must match their position"
)
save_annotation("Updated blank")
assert(annotations.exports.count() == count_before_blank + 1)
burn()
assert(table.concat(vim.api.nvim_buf_get_lines(blank, 0, -1, false), "\n"):find("<original>\n\n</original>", 1, true))

local collapsed = create_buffer({ "abcd" })
add_annotation(1, "First collapsed", "vl")
add_annotation(1, "Second collapsed", "llvl")
vim.api.nvim_buf_set_text(collapsed, 0, 0, 0, 4, { "" })
vim.ui.select = function(items, opts, on_choice)
  choices = vim.tbl_map(opts.format_item, items)
  on_choice(items[2])
end
open_annotation(1, "v")
assert(
  vim.deep_equal(choices, {
    "1:1–1:1 — First collapsed",
    "1:1–1:1 — Second collapsed",
  }),
  vim.inspect(choices)
)
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "Second collapsed" }))
save_annotation("Edited collapsed")
vim.ui.select = select
assert(
  rendered_text(collapsed) == "├─ 󰙏 First collapsed\n╰─ 󰙏 Edited collapsed",
  "coincident ranges must share a connected guide and retain ID order"
)
burn()
local collapsed_content = table.concat(vim.api.nvim_buf_get_lines(collapsed, 0, -1, false), "\n")
local first_collapsed =
  assert(collapsed_content:find("<original>\nab\n</original>\n<comment>\nFirst collapsed", 1, true))
local second_collapsed =
  assert(collapsed_content:find("<original>\ncd\n</original>\n<comment>\nEdited collapsed", 1, true))
assert(first_collapsed < second_collapsed, "burning coincident ranges must preserve both snapshots in ID order")

print("ok: annotations preserve selections, support multiline drafts, track source edits, and cancel without changes")
print(
  "ok: same-line annotations target exact ranges or cursor hits, disambiguate overlaps, and preserve ordered independent notes"
)
print("ok: delayed choices track source movement and reject removed annotations without leaking or redirecting drafts")

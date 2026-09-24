local colors = require("config/colors-hex")

local range_namespace = vim.api.nvim_create_namespace("workflow-annotations-range")
local render_namespace = vim.api.nvim_create_namespace("workflow-annotations-render")

local annotation_icon = "󰙏"
local unavailable_source_message = "Annotation source is no longer available"

---@class AnnotationRange
---@field bufnr number
---@field start_row number
---@field start_col number
---@field end_row number
---@field end_col number
---@field source "normal"|"visual"
---@field selection_kind "line"|"linewise"|"charwise"|"block"
---@field segments AnnotationRange[]|nil

---@class AnnotationAnchor
---@field bufnr number
---@field range_ids number[]

---@class Annotation: AnnotationAnchor
---@field id number
---@field comment string
---@field original_code string

---@class LocatedAnnotation
---@field annotation Annotation
---@field range AnnotationRange

---@class AnnotationLayout: LocatedAnnotation
---@field column number

local state = {
  next_id = 1,
  ---@type table<number, Annotation>
  annotations = {},
  ---@type table<number, number[]>
  by_buffer = {},
  ---@type Annotation[]|nil
  restore_backup = nil,
}

local function discard_restore_backup()
  for _, annotation in ipairs(state.restore_backup or {}) do
    if vim.api.nvim_buf_is_valid(annotation.bufnr) then
      for _, range_id in ipairs(annotation.range_ids) do
        pcall(vim.api.nvim_buf_del_extmark, annotation.bufnr, range_namespace, range_id)
      end
    end
  end

  state.restore_backup = nil
end

local function refresh_statusline()
  local ok, lualine = pcall(require, "lualine")
  if ok then
    lualine.refresh({ place = { "statusline" } })
  else
    vim.cmd("redrawstatus")
  end
end

---@param bufnr number
---@param row number
---@return number
local function get_line_byte_length(bufnr, row)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  return #line
end

---@param mode string
---@return boolean
local function is_visual_mode(mode)
  return mode == "v" or mode == "V" or mode == "\22"
end

---@param left_row number
---@param left_col number
---@param right_row number
---@param right_col number
---@return boolean
local function is_before(left_row, left_col, right_row, right_col)
  return left_row < right_row or (left_row == right_row and left_col < right_col)
end

---@param left_row number
---@param left_col number
---@param right_row number
---@param right_col number
---@return boolean
local function is_before_or_equal(left_row, left_col, right_row, right_col)
  return left_row < right_row or (left_row == right_row and left_col <= right_col)
end

---@param left AnnotationRange
---@param right AnnotationRange
---@return boolean
local function ranges_equal(left, right)
  if left.segments or right.segments then
    local left_segments = left.segments or { left }
    local right_segments = right.segments or { right }
    if #left_segments ~= #right_segments then return false end
    for index, segment in ipairs(left_segments) do
      if not ranges_equal(segment, right_segments[index]) then return false end
    end
    return true
  end

  return left.start_row == right.start_row
    and left.start_col == right.start_col
    and left.end_row == right.end_row
    and left.end_col == right.end_col
end

---@param range AnnotationRange
---@param row number
---@param col number
---@return boolean
local function range_contains_position(range, row, col)
  if range.segments then
    for _, segment in ipairs(range.segments) do
      if range_contains_position(segment, row, col) then return true end
    end
    return false
  end

  if range.start_row == range.end_row and range.start_col == range.end_col then
    return row == range.start_row and col == range.start_col
  end

  return is_before_or_equal(range.start_row, range.start_col, row, col)
    and is_before(row, col, range.end_row, range.end_col)
end

---@param left LocatedAnnotation
---@param right LocatedAnnotation
---@return boolean
local function is_annotation_before(left, right)
  if left.range.start_row ~= right.range.start_row then return left.range.start_row < right.range.start_row end
  if left.range.start_col ~= right.range.start_col then return left.range.start_col < right.range.start_col end
  if left.range.end_row ~= right.range.end_row then return left.range.end_row < right.range.end_row end
  if left.range.end_col ~= right.range.end_col then return left.range.end_col < right.range.end_col end
  return left.annotation.id < right.annotation.id
end

---@param bufnr number
---@param row number
---@param col number
---@return number, number
local function clamp_position(bufnr, row, col)
  local max_row = math.max(vim.api.nvim_buf_line_count(bufnr) - 1, 0)
  local clamped_row = math.min(math.max(row, 0), max_row)
  local max_col = get_line_byte_length(bufnr, clamped_row)
  local clamped_col = math.min(math.max(col, 0), max_col)
  return clamped_row, clamped_col
end

---@param annotation AnnotationAnchor
---@return AnnotationRange|nil
local function get_annotation_range(annotation)
  if not vim.api.nvim_buf_is_valid(annotation.bufnr) then return nil end

  local segments = {}
  for _, range_id in ipairs(annotation.range_ids) do
    local ok, extmark =
      pcall(vim.api.nvim_buf_get_extmark_by_id, annotation.bufnr, range_namespace, range_id, { details = true })
    if not ok or not extmark or vim.tbl_isempty(extmark) then return nil end

    local details = extmark[3] or {}
    local end_row = details.end_row
    local end_col = details.end_col
    if end_row == nil or end_col == nil then return nil end

    local start_row, start_col = clamp_position(annotation.bufnr, extmark[1], extmark[2])
    end_row, end_col = clamp_position(annotation.bufnr, end_row, end_col)
    segments[#segments + 1] = {
      bufnr = annotation.bufnr,
      start_row = start_row,
      start_col = start_col,
      end_row = end_row,
      end_col = end_col,
      source = "normal",
      selection_kind = "line",
    }
  end

  if #segments == 1 then return segments[1] end

  return {
    bufnr = annotation.bufnr,
    start_row = segments[1].start_row,
    start_col = segments[1].start_col,
    end_row = segments[#segments].end_row,
    end_col = segments[#segments].end_col,
    source = "normal",
    selection_kind = "block",
    segments = segments,
  }
end

---@param target AnnotationRange
---@return string
local function capture_original_code(target)
  if target.source == "visual" then
    local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
    return table.concat(lines, "\n")
  end

  local lines = vim.api.nvim_buf_get_lines(target.bufnr, target.start_row, target.end_row + 1, false)
  return table.concat(lines, "\n")
end

---@param annotations AnnotationLayout[]
---@return table[]
local function build_virtual_lines(annotations)
  table.sort(annotations, function(left, right)
    if left.column ~= right.column then return left.column > right.column end
    return is_annotation_before(left, right)
  end)

  local pending_columns = {}
  for _, item in ipairs(annotations) do
    pending_columns[item.column] = (pending_columns[item.column] or 0) + 1
  end

  local virt_lines = {}
  for _, item in ipairs(annotations) do
    local padding_cells = {}
    for column = 0, item.column - 1 do
      padding_cells[#padding_cells + 1] = pending_columns[column] and "│" or " "
    end
    local padding = table.concat(padding_cells)

    pending_columns[item.column] = pending_columns[item.column] - 1
    local continues = pending_columns[item.column] > 0
    if not continues then pending_columns[item.column] = nil end

    local lines = vim.split(item.annotation.comment, "\n", { plain = true, trimempty = false })
    if #lines <= 1 then
      local prefix = continues and "├─ " or "╰─ "
      virt_lines[#virt_lines + 1] = {
        { padding .. prefix, "AnnotationsGuide" },
        { annotation_icon .. " ", "AnnotationsIcon" },
        { lines[1] or "", "AnnotationsText" },
      }
    else
      virt_lines[#virt_lines + 1] = {
        { padding .. "├─ ", "AnnotationsGuide" },
        { annotation_icon .. " note", "AnnotationsIcon" },
      }

      for index, line in ipairs(lines) do
        local prefix = index == #lines and not continues and "╰  " or "│  "
        virt_lines[#virt_lines + 1] = {
          { padding .. prefix, "AnnotationsGuide" },
          { line, "AnnotationsText" },
        }
      end
    end
  end

  return virt_lines
end

local function apply_highlights()
  vim.api.nvim_set_hl(0, "AnnotationsGuide", { fg = colors.yellow })
  vim.api.nvim_set_hl(0, "AnnotationsIcon", { fg = colors.yellow })
  vim.api.nvim_set_hl(0, "AnnotationsText", { fg = colors.yellow })
  vim.api.nvim_set_hl(0, "AnnotationsRange", { bg = "#443923" })
  local editor_background = "#2E291F"
  vim.api.nvim_set_hl(0, "AnnotationsEditor", { fg = colors.foreground, bg = editor_background })
  vim.api.nvim_set_hl(0, "AnnotationsEditorBorder", { fg = colors.yellow, bg = editor_background })
end

---@param bufnr number
---@return number[]
local function ensure_buffer_annotations(bufnr)
  if not state.by_buffer[bufnr] then state.by_buffer[bufnr] = {} end
  return state.by_buffer[bufnr]
end

---@param annotation Annotation
local function detach_annotation(annotation)
  local annotations = state.by_buffer[annotation.bufnr]
  if annotations then
    for index, id in ipairs(annotations) do
      if id == annotation.id then
        table.remove(annotations, index)
        break
      end
    end

    if #annotations == 0 then state.by_buffer[annotation.bufnr] = nil end
  end

  state.annotations[annotation.id] = nil
end

---@param annotation Annotation
---@param opts? { skip_range_delete?: boolean }
local function remove_annotation(annotation, opts)
  opts = opts or {}

  if not opts.skip_range_delete and vim.api.nvim_buf_is_valid(annotation.bufnr) then
    for _, range_id in ipairs(annotation.range_ids) do
      pcall(vim.api.nvim_buf_del_extmark, annotation.bufnr, range_namespace, range_id)
    end
  end

  detach_annotation(annotation)
end

---@param bufnr number
local function render_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  vim.api.nvim_buf_clear_namespace(bufnr, render_namespace, 0, -1)

  local stale_annotations = {}
  local annotations = {}
  for _, id in ipairs(state.by_buffer[bufnr] or {}) do
    local annotation = state.annotations[id]
    local range = annotation and get_annotation_range(annotation) or nil

    if not annotation or not range then
      if annotation then stale_annotations[#stale_annotations + 1] = annotation end
    else
      annotations[#annotations + 1] = { annotation = annotation, range = range }
    end
  end

  local annotations_by_row = {}
  for _, item in ipairs(annotations) do
    local range = item.range
    for _, segment in ipairs(range.segments or { range }) do
      vim.api.nvim_buf_set_extmark(bufnr, render_namespace, segment.start_row, segment.start_col, {
        end_row = segment.end_row,
        end_col = segment.end_col,
        hl_group = "AnnotationsRange",
        priority = 150,
        strict = false,
      })
    end
    local line = vim.api.nvim_buf_get_lines(bufnr, range.start_row, range.start_row + 1, false)[1]
    local column = math.max(range.start_col, #line:match("^%s*"))
    local width = vim.api.nvim_buf_call(bufnr, function()
      return vim.fn.strdisplaywidth(line:sub(1, column))
    end)
    item.column = width
    if not annotations_by_row[range.end_row] then annotations_by_row[range.end_row] = {} end
    table.insert(annotations_by_row[range.end_row], item)
  end

  for row, items in pairs(annotations_by_row) do
    vim.api.nvim_buf_set_extmark(bufnr, render_namespace, row, 0, {
      virt_lines = build_virtual_lines(items),
      virt_lines_above = false,
      virt_lines_leftcol = false,
      virt_lines_overflow = "trunc",
      hl_mode = "combine",
      strict = false,
    })
  end

  for _, annotation in ipairs(stale_annotations) do
    remove_annotation(annotation, { skip_range_delete = true })
  end
end

local function cleanup_invalid_annotations()
  local stale_annotations = {}
  local affected_buffers = {}

  for _, annotation in pairs(state.annotations) do
    if not vim.api.nvim_buf_is_valid(annotation.bufnr) or not get_annotation_range(annotation) then
      stale_annotations[#stale_annotations + 1] = annotation
      affected_buffers[annotation.bufnr] = true
    end
  end

  if #stale_annotations == 0 then return end

  for _, annotation in ipairs(stale_annotations) do
    remove_annotation(annotation, { skip_range_delete = true })
  end

  for bufnr in pairs(affected_buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) then render_buffer(bufnr) end
  end
end

---@param bufnr number
---@return Annotation[]
local function get_buffer_annotations(bufnr)
  local result = {}
  for _, id in ipairs(state.by_buffer[bufnr] or {}) do
    local annotation = state.annotations[id]
    if annotation then result[#result + 1] = annotation end
  end
  return result
end

---@param target AnnotationRange
---@param cursor number[]
---@return LocatedAnnotation[]
local function find_matching_annotations(target, cursor)
  local matches = {}

  for _, annotation in ipairs(get_buffer_annotations(target.bufnr)) do
    local range = get_annotation_range(annotation)
    if range then
      local matches_target
      if target.source == "visual" then
        matches_target = ranges_equal(range, target)
      else
        matches_target = range_contains_position(range, cursor[1] - 1, cursor[2])
      end
      if matches_target then matches[#matches + 1] = { annotation = annotation, range = range } end
    end
  end

  table.sort(matches, is_annotation_before)
  return matches
end

---@param annotation AnnotationAnchor
---@param target AnnotationRange
local function set_annotation_range(annotation, target)
  local segments = target.segments or { target }
  for index, segment in ipairs(segments) do
    annotation.range_ids[index] =
      vim.api.nvim_buf_set_extmark(annotation.bufnr, range_namespace, segment.start_row, segment.start_col, {
        end_row = segment.end_row,
        end_col = segment.end_col,
        right_gravity = false,
        end_right_gravity = true,
        strict = false,
      })
  end
end

---@param target AnnotationRange
---@param original_code string
---@param comment string
local function create_annotation(target, original_code, comment)
  discard_restore_backup()

  local annotation = {
    id = state.next_id,
    bufnr = target.bufnr,
    range_ids = {},
    comment = comment,
    original_code = original_code,
  }

  state.next_id = state.next_id + 1
  state.annotations[annotation.id] = annotation
  ensure_buffer_annotations(target.bufnr)[#ensure_buffer_annotations(target.bufnr) + 1] = annotation.id

  set_annotation_range(annotation, target)
  render_buffer(target.bufnr)

  return annotation
end

---@param annotation Annotation
---@param comment string
local function update_annotation(annotation, comment)
  annotation.comment = comment
  render_buffer(annotation.bufnr)
end

---@return number
local function count_annotations()
  cleanup_invalid_annotations()

  local count = 0
  for _ in pairs(state.annotations) do
    count = count + 1
  end
  return count
end

---@param bufnr number
---@return string
local function get_relative_path(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then return string.format("[buf %d]", bufnr) end

  local relative_path = vim.fn.fnamemodify(path, ":.")
  if relative_path == "" then return path end
  return relative_path
end

---@param bufnr number
---@return string
local function get_code_fence_language(bufnr)
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
  return filetype or ""
end

local function burn_annotations()
  cleanup_invalid_annotations()

  local bufnr = vim.api.nvim_get_current_buf()
  local annotations = {}
  for _, annotation in ipairs(get_buffer_annotations(bufnr)) do
    local range = get_annotation_range(annotation)
    if range then annotations[#annotations + 1] = { annotation = annotation, range = range } end
  end

  if #annotations == 0 then return end

  table.sort(annotations, function(left, right)
    if left.range.end_row ~= right.range.end_row then return left.range.end_row > right.range.end_row end
    if left.range.start_col ~= right.range.start_col then return left.range.start_col > right.range.start_col end
    return is_annotation_before(right, left)
  end)

  for index, item in ipairs(annotations) do
    local range = item.range
    local lines = { "<annotation>", "<original>" }
    vim.list_extend(lines, vim.split(item.annotation.original_code, "\n", { plain = true, trimempty = false }))
    vim.list_extend(lines, { "</original>", "<comment>" })
    vim.list_extend(lines, vim.split(item.annotation.comment, "\n", { plain = true, trimempty = false }))
    vim.list_extend(lines, { "</comment>", "</annotation>" })

    if index > 1 then vim.cmd("undojoin") end
    vim.api.nvim_buf_set_lines(bufnr, range.end_row + 1, range.end_row + 1, false, lines)
    remove_annotation(item.annotation)
  end

  render_buffer(bufnr)
  refresh_statusline()
  return true
end

local function export_annotations()
  cleanup_invalid_annotations()

  local annotations = {}
  for _, annotation in pairs(state.annotations) do
    local range = get_annotation_range(annotation)
    if range then
      annotations[#annotations + 1] = {
        annotation = annotation,
        range = range,
        relative_path = get_relative_path(annotation.bufnr),
      }
    end
  end

  if #annotations == 0 then
    vim.notify("No annotations to export", vim.log.levels.INFO)
    return
  end

  table.sort(annotations, function(left, right)
    if left.relative_path == right.relative_path then return is_annotation_before(left, right) end
    return left.relative_path < right.relative_path
  end)

  local blocks = {}
  for _, item in ipairs(annotations) do
    local annotation = item.annotation
    local range = item.range
    local line_numbers = tostring(range.start_row + 1)
    if range.end_row ~= range.start_row then line_numbers = string.format("%s-%d", line_numbers, range.end_row + 1) end

    local code_fence_language = get_code_fence_language(annotation.bufnr)
    local code_fence = "```"
    if code_fence_language ~= "" then code_fence = code_fence .. code_fence_language end

    blocks[#blocks + 1] = table.concat({
      string.format("### `%s` lines %s", item.relative_path, line_numbers),
      "",
      code_fence,
      annotation.original_code,
      "```",
      "",
      "Comment:",
      annotation.comment,
    }, "\n")
  end

  local content = table.concat(blocks, "\n\n")
  vim.fn.setreg("+", content)
  vim.notify(string.format("Copied %d annotation%s to clipboard", #annotations, #annotations == 1 and "" or "s"))
end

---@return number
local function restore_cleared_annotations()
  local backup = state.restore_backup
  state.restore_backup = nil

  if not backup then return 0 end

  local buffers = {}
  local restored_count = 0

  for _, annotation in ipairs(backup) do
    if get_annotation_range(annotation) then
      state.annotations[annotation.id] = annotation
      ensure_buffer_annotations(annotation.bufnr)[#ensure_buffer_annotations(annotation.bufnr) + 1] = annotation.id
      if annotation.id >= state.next_id then state.next_id = annotation.id + 1 end

      buffers[annotation.bufnr] = true
      restored_count = restored_count + 1
    end
  end

  for bufnr in pairs(buffers) do
    render_buffer(bufnr)
  end

  return restored_count
end

local function clear_annotations()
  cleanup_invalid_annotations()

  if not next(state.annotations) and state.restore_backup then
    local restored_count = restore_cleared_annotations()
    refresh_statusline()
    if restored_count == 0 then
      vim.notify("No annotations to restore", vim.log.levels.INFO)
    else
      vim.notify(string.format("Restored %d annotation%s", restored_count, restored_count == 1 and "" or "s"))
    end
    return
  end

  local annotation_ids = {}
  local buffers = {}
  local backup = {}

  for id, annotation in pairs(state.annotations) do
    annotation_ids[#annotation_ids + 1] = id
    buffers[annotation.bufnr] = true

    if get_annotation_range(annotation) then backup[#backup + 1] = annotation end
  end

  if #annotation_ids == 0 then
    vim.notify("No annotations to clear", vim.log.levels.INFO)
    return
  end

  for _, id in ipairs(annotation_ids) do
    local annotation = state.annotations[id]
    if annotation then detach_annotation(annotation) end
  end

  state.restore_backup = backup

  for bufnr in pairs(buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) then vim.api.nvim_buf_clear_namespace(bufnr, render_namespace, 0, -1) end
  end

  refresh_statusline()
  vim.notify(string.format("Cleared %d annotation%s", #annotation_ids, #annotation_ids == 1 and "" or "s"))
end

---@return AnnotationRange
local function get_target_range()
  local bufnr = vim.api.nvim_get_current_buf()
  local mode = vim.fn.mode()

  if not is_visual_mode(mode) then
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    return {
      bufnr = bufnr,
      start_row = row,
      start_col = 0,
      end_row = row,
      end_col = get_line_byte_length(bufnr, row),
      source = "normal",
      selection_kind = "line",
    }
  end

  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")

  local start_row = start_pos[2] - 1
  local start_col = start_pos[3]
  local end_row = end_pos[2] - 1
  local end_col = end_pos[3]

  if not is_before_or_equal(start_row, start_col, end_row, end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  if mode == "V" then
    return {
      bufnr = bufnr,
      start_row = start_row,
      start_col = 0,
      end_row = end_row,
      end_col = get_line_byte_length(bufnr, end_row),
      source = "visual",
      selection_kind = "linewise",
    }
  end

  local positions = vim.fn.getregionpos(start_pos, end_pos, { type = mode, eol = true })
  local first = positions[1][1]
  local last = positions[#positions][2]
  start_row, start_col = clamp_position(bufnr, first[2] - 1, first[3] - 1)
  end_row, end_col = clamp_position(bufnr, last[2] - 1, last[3])

  local segments
  if mode == "\22" then
    segments = {}
    for _, position in ipairs(positions) do
      local segment_start_row, segment_start_col = clamp_position(bufnr, position[1][2] - 1, position[1][3] - 1)
      local segment_end_row, segment_end_col = clamp_position(bufnr, position[2][2] - 1, position[2][3])
      segments[#segments + 1] = {
        bufnr = bufnr,
        start_row = segment_start_row,
        start_col = segment_start_col,
        end_row = segment_end_row,
        end_col = segment_end_col,
        source = "visual",
        selection_kind = "charwise",
      }
    end
  end

  return {
    bufnr = bufnr,
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
    source = "visual",
    selection_kind = mode == "\22" and "block" or "charwise",
    segments = segments,
  }
end

local function leave_visual_mode()
  local escape = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(escape, "nx", false)
end

---@param anchor AnnotationAnchor
---@param opts { source_window: number, annotation?: Annotation, original_code: string }
local function open_annotation_editor(anchor, opts)
  local existing_annotation = opts.annotation
  local source_window = opts.source_window

  local discard_draft = function()
    if existing_annotation or not vim.api.nvim_buf_is_valid(anchor.bufnr) then return end

    for _, id in ipairs(anchor.range_ids) do
      vim.api.nvim_buf_del_extmark(anchor.bufnr, range_namespace, id)
    end
  end

  vim.schedule(function()
    local target = get_annotation_range(anchor)
    local annotation_removed = existing_annotation and state.annotations[existing_annotation.id] ~= existing_annotation
    if
      not target
      or annotation_removed
      or not vim.api.nvim_win_is_valid(source_window)
      or vim.api.nvim_win_get_buf(source_window) ~= anchor.bufnr
    then
      discard_draft()
      vim.notify(unavailable_source_message, vim.log.levels.ERROR)
      return
    end

    local buffer = vim.api.nvim_create_buf(false, true)
    vim.b[buffer].completion = false
    vim.bo[buffer].buftype = "acwrite"
    vim.bo[buffer].bufhidden = "wipe"
    vim.api.nvim_buf_set_name(buffer, "annotation://" .. buffer)
    vim.api.nvim_buf_set_lines(
      buffer,
      0,
      -1,
      false,
      vim.split(existing_annotation and existing_annotation.comment or "", "\n", { plain = true })
    )
    vim.bo[buffer].modified = false
    local width = math.max(1, math.min(64, vim.api.nvim_win_get_width(source_window) - 2))
    local height = math.max(
      1,
      math.min(math.max(4, vim.api.nvim_buf_line_count(buffer)), 8, vim.api.nvim_win_get_height(source_window) - 2)
    )
    local source_line = vim.api.nvim_buf_get_lines(target.bufnr, target.start_row, target.start_row + 1, false)[1]
    local column = math.max(target.start_col, #source_line:match("^%s*"))
    local screen_row = vim.fn.screenpos(source_window, target.end_row + 1, column + 1).row
    local below = screen_row + height + 2 <= vim.o.lines - vim.o.cmdheight
    local window = vim.api.nvim_open_win(buffer, true, {
      relative = "win",
      win = source_window,
      bufpos = { target.end_row, column },
      width = width,
      height = height,
      row = below and 1 or 0,
      col = 0,
      anchor = below and "NW" or "SW",
      style = "minimal",
      border = "rounded",
      title = existing_annotation and " Edit annotation " or " Add annotation ",
    })
    vim.wo[window].wrap = true
    vim.wo[window].winblend = 0
    vim.wo[window].winhighlight =
      "Normal:AnnotationsEditor,NormalFloat:AnnotationsEditor,FloatBorder:AnnotationsEditorBorder,FloatTitle:AnnotationsEditorBorder"

    local close = function()
      vim.cmd.stopinsert()
      vim.api.nvim_win_close(window, true)
    end

    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = buffer,
      once = true,
      callback = discard_draft,
    })

    local submit = function()
      local range = get_annotation_range(anchor)
      local annotation_removed = existing_annotation
        and state.annotations[existing_annotation.id] ~= existing_annotation
      if not range or annotation_removed then
        discard_draft()
        vim.notify(unavailable_source_message, vim.log.levels.ERROR)
        return
      end

      local comment = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), "\n"))
      if comment == "" then
        if existing_annotation then
          remove_annotation(existing_annotation)
          render_buffer(target.bufnr)
          refresh_statusline()
        end
        close()
        return
      end

      if existing_annotation then
        update_annotation(existing_annotation, comment)
      else
        create_annotation(range, opts.original_code, comment)
      end

      refresh_statusline()
      close()
    end

    vim.api.nvim_create_autocmd("BufWriteCmd", { buffer = buffer, nested = true, callback = submit })
    vim.api.nvim_create_autocmd("QuitPre", { buffer = buffer, nested = true, callback = close })
    vim.keymap.set({ "n", "i" }, "<C-s>", submit, { buffer = buffer, desc = "Submit annotation" })
    vim.keymap.set("n", "q", close, { buffer = buffer, desc = "Cancel annotation" })
    vim.cmd.startinsert()
  end)
end

local function handle_annotation_prompt()
  cleanup_invalid_annotations()

  local target = get_target_range()
  local matches = find_matching_annotations(target, vim.api.nvim_win_get_cursor(0))
  local captured_code = capture_original_code(target)
  local source_window = vim.api.nvim_get_current_win()

  if target.source == "visual" then leave_visual_mode() end

  if #matches == 0 then
    local draft = { bufnr = target.bufnr, range_ids = {} }
    set_annotation_range(draft, target)
    open_annotation_editor(draft, { source_window = source_window, original_code = captured_code })
    return
  end

  local edit_annotation = function(item)
    if not item then return end

    open_annotation_editor(item.annotation, {
      source_window = source_window,
      annotation = item.annotation,
      original_code = item.annotation.original_code,
    })
  end

  if #matches == 1 then
    edit_annotation(matches[1])
    return
  end

  vim.ui.select(matches, {
    prompt = "Select annotation",
    format_item = function(item)
      local range = item.range
      return string.format(
        "%d:%d–%d:%d — %s",
        range.start_row + 1,
        range.start_col + 1,
        range.end_row + 1,
        math.max(range.end_col, range.start_row == range.end_row and range.start_col + 1 or 1),
        item.annotation.comment:gsub("\n", " ")
      )
    end,
  }, edit_annotation)
end

local function statusline_component()
  local count = count_annotations()
  if count == 0 then return "" end
  return string.format("%s %d", annotation_icon, count)
end

local function setup()
  apply_highlights()

  local group = vim.api.nvim_create_augroup("workflow-annotations", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = apply_highlights,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufEnter" }, {
    group = group,
    callback = function(args)
      if state.by_buffer[args.buf] then render_buffer(args.buf) end
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      local annotations = get_buffer_annotations(args.buf)
      if #annotations == 0 then return end

      for _, annotation in ipairs(annotations) do
        remove_annotation(annotation, { skip_range_delete = true })
      end

      refresh_statusline()
    end,
  })
end

return lib.module.create({
  name = "workflow/annotations",
  hosts = "*",
  setup = setup,
  actions = {
    {
      "n",
      "Annotations: Burn annotations into current file",
      burn_annotations,
      function()
        cleanup_invalid_annotations()
        return #(state.by_buffer[vim.api.nvim_get_current_buf()] or {}) > 0
      end,
    },
  },
  mappings = {
    { { "n", "v" }, "<leader>n", handle_annotation_prompt, { desc = "Annotations: Add or edit" } },
    { { "n", "v" }, "<leader>N", export_annotations, { desc = "Annotations: Copy all" } },
    { { "n", "v" }, "<leader><leader>n", clear_annotations, { desc = "Annotations: Clear all" } },
  },
  exports = {
    burn = burn_annotations,
    count = count_annotations,
    statusline = statusline_component,
  },
})

local colors = require("config/colors-hex")

local range_namespace = vim.api.nvim_create_namespace("workflow-annotations-range")
local render_namespace = vim.api.nvim_create_namespace("workflow-annotations-render")

local annotation_icon = "󰙏"

---@class AnnotationRange
---@field bufnr number
---@field start_row number
---@field start_col number
---@field end_row number
---@field end_col number
---@field source "normal"|"visual"
---@field selection_kind "line"|"linewise"|"charwise"|"block"

---@class Annotation
---@field id number
---@field bufnr number
---@field range_id number|nil
---@field comment string
---@field original_code string

local state = {
  next_id = 1,
  ---@type table<number, Annotation>
  annotations = {},
  ---@type table<number, number[]>
  by_buffer = {},
}

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
  return left.start_row == right.start_row
    and left.start_col == right.start_col
    and left.end_row == right.end_row
    and left.end_col == right.end_col
end

---@param left AnnotationRange
---@param right AnnotationRange
---@return boolean
local function ranges_overlap(left, right)
  return is_before(left.start_row, left.start_col, right.end_row, right.end_col)
    and is_before(right.start_row, right.start_col, left.end_row, left.end_col)
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

---@param annotation Annotation
---@return AnnotationRange|nil
local function get_annotation_range(annotation)
  if not vim.api.nvim_buf_is_valid(annotation.bufnr) then return nil end

  local ok, extmark =
    pcall(vim.api.nvim_buf_get_extmark_by_id, annotation.bufnr, range_namespace, annotation.range_id, {
      details = true,
    })
  if not ok or not extmark or vim.tbl_isempty(extmark) then return nil end

  local details = extmark[3] or {}
  local end_row = details.end_row
  local end_col = details.end_col
  if end_row == nil or end_col == nil then return nil end

  local start_row, start_col = clamp_position(annotation.bufnr, extmark[1], extmark[2])
  end_row, end_col = clamp_position(annotation.bufnr, end_row, end_col)

  return {
    bufnr = annotation.bufnr,
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
    source = "normal",
    selection_kind = "line",
  }
end

---@param target AnnotationRange
---@return string
local function capture_original_code(target)
  if target.selection_kind == "charwise" then
    local lines =
      vim.api.nvim_buf_get_text(target.bufnr, target.start_row, target.start_col, target.end_row, target.end_col, {})
    return table.concat(lines, "\n")
  end

  local lines = vim.api.nvim_buf_get_lines(target.bufnr, target.start_row, target.end_row + 1, false)
  return table.concat(lines, "\n")
end

---@param comment string
---@return table[]
local function build_virtual_lines(comment)
  local lines = vim.split(comment, "\n", { plain = true, trimempty = false })

  if #lines <= 1 then
    return {
      {
        { "╰─ ", "AnnotationsGuide" },
        { annotation_icon .. " ", "AnnotationsIcon" },
        { lines[1] or "", "AnnotationsText" },
      },
    }
  end

  local virt_lines = {
    {
      { "╭─ ", "AnnotationsGuide" },
      { annotation_icon .. " note", "AnnotationsIcon" },
    },
  }

  for index, line in ipairs(lines) do
    local prefix = index == #lines and "╰  " or "│  "
    virt_lines[#virt_lines + 1] = {
      { prefix, "AnnotationsGuide" },
      { line, "AnnotationsText" },
    }
  end

  return virt_lines
end

local function apply_highlights()
  vim.api.nvim_set_hl(0, "AnnotationsGuide", { fg = colors.common.comment })
  vim.api.nvim_set_hl(0, "AnnotationsIcon", { fg = colors.yellow, bold = true })
  vim.api.nvim_set_hl(0, "AnnotationsText", { fg = colors.ui.status.c.fg })
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
    pcall(vim.api.nvim_buf_del_extmark, annotation.bufnr, range_namespace, annotation.range_id)
  end

  detach_annotation(annotation)
end

---@param bufnr number
local function render_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  vim.api.nvim_buf_clear_namespace(bufnr, render_namespace, 0, -1)

  local stale_annotations = {}
  for _, id in ipairs(state.by_buffer[bufnr] or {}) do
    local annotation = state.annotations[id]
    local range = annotation and get_annotation_range(annotation) or nil

    if not annotation or not range then
      if annotation then stale_annotations[#stale_annotations + 1] = annotation end
    else
      vim.api.nvim_buf_set_extmark(bufnr, render_namespace, range.end_row, 0, {
        virt_lines = build_virtual_lines(annotation.comment),
        virt_lines_above = false,
        virt_lines_leftcol = false,
        virt_lines_overflow = "trunc",
        hl_mode = "combine",
        strict = false,
      })
    end
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
---@return Annotation|nil, AnnotationRange|nil
local function find_matching_annotation(target)
  local overlapping_annotation = nil
  local overlapping_range = nil

  for _, annotation in ipairs(get_buffer_annotations(target.bufnr)) do
    local range = get_annotation_range(annotation)
    if range then
      if ranges_equal(range, target) then return annotation, range end
      if not overlapping_annotation and ranges_overlap(range, target) then
        overlapping_annotation = annotation
        overlapping_range = range
      end
    end
  end

  return overlapping_annotation, overlapping_range
end

---@param annotation Annotation
---@param target AnnotationRange
local function set_annotation_range(annotation, target)
  local opts = {
    end_row = target.end_row,
    end_col = target.end_col,
    right_gravity = false,
    end_right_gravity = true,
    strict = false,
  }

  if annotation.range_id and annotation.range_id > 0 then opts.id = annotation.range_id end

  annotation.range_id =
    vim.api.nvim_buf_set_extmark(annotation.bufnr, range_namespace, target.start_row, target.start_col, opts)
end

---@param target AnnotationRange
---@param original_code string
---@param comment string
local function create_annotation(target, original_code, comment)
  local annotation = {
    id = state.next_id,
    bufnr = target.bufnr,
    range_id = nil,
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
---@param target AnnotationRange
---@param existing_range AnnotationRange|nil
---@param captured_code string
---@param comment string
local function update_annotation(annotation, target, existing_range, captured_code, comment)
  annotation.comment = comment

  if target.source == "visual" and (not existing_range or not ranges_equal(existing_range, target)) then
    annotation.original_code = captured_code
    set_annotation_range(annotation, target)
  end

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
    if left.relative_path == right.relative_path then
      if left.range.start_row == right.range.start_row then return left.range.start_col < right.range.start_col end
      return left.range.start_row < right.range.start_row
    end
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

local function clear_annotations()
  local annotation_ids = {}
  local buffers = {}

  for id, annotation in pairs(state.annotations) do
    annotation_ids[#annotation_ids + 1] = id
    buffers[annotation.bufnr] = true
  end

  if #annotation_ids == 0 then
    vim.notify("No annotations to clear", vim.log.levels.INFO)
    return
  end

  for _, id in ipairs(annotation_ids) do
    local annotation = state.annotations[id]
    if annotation then
      if vim.api.nvim_buf_is_valid(annotation.bufnr) then
        pcall(vim.api.nvim_buf_del_extmark, annotation.bufnr, range_namespace, annotation.range_id)
      end
      detach_annotation(annotation)
    end
  end

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

  local visual_mode = vim.fn.visualmode()
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getcurpos()

  local start_row = start_pos[2] - 1
  local start_col = start_pos[3]
  local end_row = end_pos[2] - 1
  local end_col = end_pos[3]

  if not is_before_or_equal(start_row, start_col, end_row, end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  if visual_mode == "V" or visual_mode == "\22" then
    return {
      bufnr = bufnr,
      start_row = start_row,
      start_col = 0,
      end_row = end_row,
      end_col = get_line_byte_length(bufnr, end_row),
      source = "visual",
      selection_kind = visual_mode == "\22" and "block" or "linewise",
    }
  end

  return {
    bufnr = bufnr,
    start_row = start_row,
    start_col = math.max(start_col - 1, 0),
    end_row = end_row,
    end_col = end_col,
    source = "visual",
    selection_kind = "charwise",
  }
end

local function leave_visual_mode()
  local escape = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(escape, "nx", false)
end

local function handle_annotation_prompt()
  cleanup_invalid_annotations()

  local target = get_target_range()
  local captured_code = capture_original_code(target)
  local existing_annotation, existing_range = find_matching_annotation(target)

  if target.source == "visual" then leave_visual_mode() end

  vim.schedule(function()
    vim.ui.input({
      prompt = existing_annotation and "Edit annotation: " or "Add annotation: ",
      default = existing_annotation and existing_annotation.comment or "",
    }, function(input)
      if input == nil then return end

      local comment = vim.trim(input)
      if comment == "" then
        if existing_annotation then
          remove_annotation(existing_annotation)
          render_buffer(target.bufnr)
          refresh_statusline()
          vim.notify("Annotation removed")
        end
        return
      end

      if existing_annotation then
        update_annotation(existing_annotation, target, existing_range, captured_code, comment)
        vim.notify("Annotation updated")
      else
        create_annotation(target, captured_code, comment)
        vim.notify("Annotation added")
      end

      refresh_statusline()
    end)
  end)
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
  mappings = {
    { { "n", "v" }, "<leader>n", handle_annotation_prompt, { desc = "Annotations: Add or edit" } },
    { { "n", "v" }, "<leader>N", export_annotations, { desc = "Annotations: Copy all" } },
    { { "n", "v" }, "<leader><leader>n", clear_annotations, { desc = "Annotations: Clear all" } },
  },
  exports = {
    count = count_annotations,
    statusline = statusline_component,
  },
})

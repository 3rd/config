local slib = require("syslang/lib")

local outline_levels = {
  outline_1 = 1,
  outline_2 = 2,
  outline_3 = 3,
  outline_4 = 4,
  outline_5 = 5,
  outline_6 = 6,
}

local get_current_outline = function()
  local root = slib.get_root()
  if not root then return end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local line = vim.api.nvim_get_current_line()
  local col = math.min(cursor[2], math.max(#line - 1, 0))
  local node = root:named_descendant_for_range(row, col, row, col)

  while node do
    local start_row = node:range()
    if start_row ~= row then return end
    if outline_levels[node:type()] then return node end
    node = node:parent()
  end
end

local get_outline_rows = function(root)
  local rows = {}
  local highest_level = 0

  local collect
  collect = function(node)
    local level = outline_levels[node:type()]
    if level then
      local row = node:range()
      rows[row] = true
      highest_level = math.max(highest_level, level)
    end

    for child in node:iter_children() do
      collect(child)
    end
  end

  collect(root)
  return rows, highest_level
end

local get_indent_unit = function(width)
  if vim.bo.expandtab then return string.rep(" ", width) end

  local tabstop = vim.bo.tabstop
  return string.rep("\t", math.floor(width / tabstop)) .. string.rep(" ", width % tabstop)
end

local remove_indent = function(line, width)
  if line == "" then return line end

  local index = 1
  local column = 0
  local tabstop = vim.bo.tabstop

  while column < width do
    local char = line:sub(index, index)
    if char == " " then
      column = column + 1
      index = index + 1
    elseif char == "\t" then
      local next_column = column + tabstop - (column % tabstop)
      index = index + 1
      if next_column > width then return string.rep(" ", next_column - width) .. line:sub(index) end
      column = next_column
    else
      if line:match("^%s*$") then return "" end
      return
    end
  end

  return line:sub(index)
end

local adjust_outline_marker = function(line, level_change)
  local adjusted
  local count
  if level_change > 0 then
    adjusted, count = line:gsub("^(%s*)(%*+ )", "%1*%2", 1)
  else
    adjusted, count = line:gsub("^(%s*)%*(%*+ )", "%1%2", 1)
  end

  if count == 0 then return end
  return adjusted
end

local shift_outline = function(level_change)
  local outline = get_current_outline()
  if not outline then return false end

  local level = outline_levels[outline:type()]
  local outline_rows, highest_level = get_outline_rows(outline)
  if level_change < 0 and level == 1 then return true end
  if level_change > 0 and highest_level == 6 then return true end

  local start_row, _, end_row, end_col = outline:range()
  local end_line = end_row + (end_col > 0 and 1 or 0)
  local lines = vim.api.nvim_buf_get_lines(0, start_row, end_line, false)
  local original_root_line = lines[1]
  local indent_width = vim.fn.shiftwidth()
  local indent_unit = get_indent_unit(indent_width)

  for index, line in ipairs(lines) do
    local row = start_row + index - 1

    if level_change > 0 then
      if line ~= "" then line = indent_unit .. line end
    else
      line = remove_indent(line, indent_width)
      if not line then return true end
    end

    if outline_rows[row] then
      line = adjust_outline_marker(line, level_change)
      if not line then return true end
    end

    lines[index] = line
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local next_level = level + level_change
  local indent = original_root_line:match("^%s*") or ""
  local next_indent = lines[1]:match("^%s*") or ""
  local separator_col = #indent + level
  local next_separator_col = #next_indent + next_level
  local next_cursor_col

  if cursor[2] >= separator_col then
    next_cursor_col = next_separator_col + cursor[2] - separator_col
  elseif cursor[2] >= #indent then
    next_cursor_col = #next_indent + cursor[2] - #indent
  else
    next_cursor_col = math.min(cursor[2], #next_indent)
  end

  vim.api.nvim_buf_set_lines(0, start_row, end_line, false, lines)
  vim.api.nvim_win_set_cursor(0, { cursor[1], math.min(next_cursor_col, math.max(#lines[1] - 1, 0)) })
  return true
end

local handle_indent = function()
  if shift_outline(1) then return end
  vim.cmd("normal! >>")
end

local handle_dedent = function()
  if shift_outline(-1) then return end
  vim.cmd("normal! <<")
end

return {
  handle_indent = handle_indent,
  handle_dedent = handle_dedent,
}

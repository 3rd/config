local function create_float_win(height, width)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    border = "single",
  })
  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = win })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
  vim.api.nvim_set_option_value("sidescrolloff", 0, { win = win })
  return buf, win
end

local function gen_dates(year, month)
  local os_time = os.time({ year = year, month = month, day = 1 })
  local first_day = os.date("*t", os_time).wday - 1 -- Sunday=0
  local days_in_month = os.date("*t", os.time({ year = year, month = month + 1, day = 0 })).day

  local lines = { "Su Mo Tu We Th Fr Sa" }
  local line = string.rep("   ", first_day)

  for day = 1, days_in_month do
    line = line .. string.format("%2d ", day)
    if (#line / 3) % 7 == 0 then
      table.insert(lines, line:sub(1, -2))
      line = ""
    end
  end

  if #line > 0 then table.insert(lines, line:sub(1, -2)) end

  local max_line_length = 0
  for _, curr in ipairs(lines) do
    max_line_length = math.max(max_line_length, #curr)
  end

  local month_name = os.date("%B", os.time({ year = year, month = month, day = 1 }))
  local header =
    string.format("Date%-" .. (max_line_length - 5 - #month_name - #tostring(year)) .. "s%s %d", "", month_name, year)
  table.insert(lines, 1, header)

  return lines, max_line_length
end

local function setup_navigation(buf, start_line, start_col)
  vim.api.nvim_win_set_cursor(0, { start_line, start_col })

  local function navigate_date(dir)
    local pos = vim.api.nvim_win_get_cursor(0)
    local max_line = #vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if dir == "down" and pos[1] < max_line then pos[1] = pos[1] + 1 end
    if dir == "up" and pos[1] > 3 then pos[1] = pos[1] - 1 end
    vim.api.nvim_win_set_cursor(0, pos)
  end

  local function select_date()
    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_buf_get_lines(buf, pos[1] - 1, pos[1], false)[1]
    local col_start = pos[2]
    local col_end = col_start + 2
    local date_str = line:sub(col_start + 1, col_end)
    print("Selected date: " .. date_str)
    vim.api.nvim_win_close(0, true)
  end

  vim.keymap.set("n", "<cr>", select_date, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "j", function()
    navigate_date("down")
  end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "k", function()
    navigate_date("up")
  end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(0, true)
  end, { buffer = buf, silent = true, nowait = true })
end

local function show_datepicker()
  local current_time = os.date("*t", os.time())
  local year, month, day = current_time.year, current_time.month, current_time.day
  local dates, max_line_length = gen_dates(year, month)

  local width = max_line_length + 1
  local height = #dates

  local start_line, start_col
  for line_idx, line in ipairs(dates) do
    start_col = line:find(string.format("%2d", day))
    if start_col then
      start_line = line_idx
      break
    end
  end

  local buf, win = create_float_win(height, width)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, dates)
  vim.schedule(function()
    vim.api.nvim_set_current_win(win)
    setup_navigation(buf, start_line, start_col - 1)
  end)
end

return {
  show = show_datepicker,
}

local folding = require("syslang/folding")
local slib = require("syslang/lib")

_G.SyslangHeadlineGutterRows = _G.SyslangHeadlineGutterRows or {}

local get_syslang_headline_gutter_rows = function()
  _G.SyslangHeadlineGutterRows = _G.SyslangHeadlineGutterRows or {}
  return _G.SyslangHeadlineGutterRows
end

local setup_options = function()
  vim.opt_local.foldlevel = 999
  vim.opt_local.wrap = true
  vim.opt_local.signcolumn = "yes:1"
  vim.opt_local.statuscolumn = "%{%v:lua.SyslangStatuscolumn()%}"
  vim.opt_local.number = false
  vim.opt_local.breakindent = true
  vim.opt_local.linebreak = true
  vim.opt_local.cursorlineopt = "screenline"
  vim.opt_local.winbar = " "
  vim.opt_local.commentstring = "-- %s"
  vim.opt_local.breakindentopt = "list:-1"
  vim.opt_local.formatlistpat = [[ ^\s*(\d)\+\s* ]]
  vim.opt_local.formatoptions = "cqrt"
  vim.opt_local.cinwords = "*,-"
  vim.opt_local.textwidth = 130
  vim.opt_local.concealcursor = "nc"
end

_G.SyslangStatuscolumn = function()
  local row = vim.v.lnum
  local bufnr = vim.api.nvim_get_current_buf()
  local gutter_rows = get_syslang_headline_gutter_rows()[bufnr] or {}
  local gutter = gutter_rows[row]
  local fill_char = " "
  local fill_highlight = "SignColumn"
  local margin_char = " "
  local margin_highlight = "SyslangMargin"

  if type(gutter) == "table" then
    fill_char = gutter.char
    fill_highlight = gutter.hl
    margin_char = gutter.margin_char or margin_char
    margin_highlight = gutter.margin_hl or margin_highlight
  end

  return "%#" .. fill_highlight .. "#" .. fill_char .. "%#" .. margin_highlight .. "#" .. margin_char .. "%*"
end

-- it takes a while for the fold info to be updated by ts on its own
-- local delayed_fold_close = function(row_number)
--   vim.defer_fn(function()
--     vim.api.nvim_command("silent! " .. row_number .. " foldclose")
--   end, 500)
-- end

--- @param task_node TSNode
local transition_task_active_to_done = function(task_node)
  local task_text_node = task_node:child(1)
  if not task_text_node then return end
  local _, _, task_text_end_row, task_text_end_col = task_text_node:range()

  local indent = vim.fn.indent(vim.fn.line("."))

  -- store task position
  local parent = task_node:parent()
  local child_row, _, end_row = task_node:range()
  local parent_row = parent and parent:range() or nil

  while parent and parent_row and child_row == parent_row do
    parent = parent:parent()
    parent_row = parent and parent:range() or nil
  end

  if not parent then return end
  local index_of_task = nil
  local num_children = parent:named_child_count()
  local first_task_index = nil
  local last_done_task_index = nil

  -- find task indices
  for i = 0, num_children - 1 do
    local current_child = parent:named_child(i)
    if not current_child then return end
    local curren_child_row = current_child:range()
    if curren_child_row == child_row then
      index_of_task = i
    else
      if current_child then
        local child_type = current_child:type()
        if child_type == "task_done" then
          last_done_task_index = i
          if first_task_index and i > first_task_index then first_task_index = nil end
        else
          if child_type == "task_default" or child_type == "task_active" then
            if not first_task_index then first_task_index = i end
          else
            first_task_index = nil
            last_done_task_index = nil
          end
        end
      end
    end
  end

  if not index_of_task then return error("index_of_task is nil") end

  -- handle sessions
  local sessions = lib.ts.find_children(task_node, "task_session")
  local active_sessions = {}

  -- active sessions have a single (time) node
  for _, session_node in ipairs(sessions) do
    local time_nodes = lib.ts.find_children(session_node, "time", true)
    if #time_nodes == 1 then table.insert(active_sessions, session_node) end
  end

  -- if there are no sessions, create an instant one
  if #sessions == 0 then
    local session_text = "Session: " .. os.date("%Y.%m.%d %H:%M-%H:%M") .. "\n"
    session_text = string.rep(" ", indent + vim.bo.tabstop) .. session_text
    local range = {
      start = { line = task_text_end_row, character = task_text_end_col },
      ["end"] = { line = task_text_end_row, character = task_text_end_col },
    }
    local edit = { range = range, newText = session_text }
    local buf = vim.api.nvim_get_current_buf()
    vim.lsp.util.apply_text_edits({ edit }, buf, "utf-8")

    -- account for the new session line
    end_row = end_row + 1
  else
    -- if there are active sessions, close them
    if #active_sessions ~= 0 then
      for _, session_node in ipairs(active_sessions) do
        local datetime_node = lib.ts.find_child(session_node, "datetime", true)
        local start_date_node = lib.ts.find_child(session_node, "date", true)
        local start_time_node = lib.ts.find_child(session_node, "time", true)
        if not start_date_node or not start_time_node then return end
        local start_date = vim.treesitter.get_node_text(start_date_node, 0)
        local start_time = vim.treesitter.get_node_text(start_time_node, 0)
        local end_date = os.date("%Y.%m.%d")
        local end_time = os.date("%H:%M")
        local range = slib.node_to_lsp_range(datetime_node)
        local text = string.format("%s %s - %s %s", start_date, start_time, end_date, end_time)
        if start_date == end_date then text = string.format("%s %s-%s", start_date, start_time, end_time) end
        local edit = { range = range, newText = text }
        local buf = vim.api.nvim_get_current_buf()
        vim.lsp.util.apply_text_edits({ edit }, buf, "utf-8")
      end
    end
  end

  -- bail if first or preceded by a done task
  if last_done_task_index == index_of_task - 1 or (last_done_task_index == nil and first_task_index == nil) then
    -- -- auto-fold
    -- local row = task_node:range() + 1
    -- delayed_fold_close(row)
    return
  end

  -- get target
  local target_index = math.max(last_done_task_index or 0, first_task_index or 0)
  if not target_index then return end
  local target_node = parent:named_child(target_index)
  if not target_node then return end

  local target_start_row = target_node:range()
  if child_row < target_start_row then target_start_row = target_start_row + 1 end

  -- move the task and session
  vim.cmd(string.format("%d,%dm%d", child_row + 1, end_row, target_start_row))

  -- TODO: fix empty line inserted when at the end of the file and there's no trailing newline
  -- TODO: move cursor
  -- delayed_fold_close(target_start_row + 1)
end

local transition_task_done_to_default = function(task_node)
  local sessions = lib.ts.find_children(task_node, "task_session")
  local line_offset = 0
  for _, session_node in ipairs(sessions) do
    local time_nodes = lib.ts.find_children(session_node, "time", true)
    if #time_nodes == 2 then
      local date_nodes = lib.ts.find_children(session_node, "date", true)
      local start_date = vim.treesitter.get_node_text(date_nodes[1], 0)
      local start_time = vim.treesitter.get_node_text(time_nodes[1], 0)
      local end_date = start_date
      if #date_nodes == 2 then end_date = vim.treesitter.get_node_text(date_nodes[2], 0) end
      local end_time = vim.treesitter.get_node_text(time_nodes[#time_nodes], 0)
      if start_date == end_date and start_time == end_time then
        local range = slib.node_to_lsp_range(session_node)
        range.start.line = range.start.line - line_offset
        range.start.character = 0
        range["end"].line = range["end"].line + 1 - line_offset
        range["end"].character = 0
        local edit = { range = range, newText = "" }
        local buf = vim.api.nvim_get_current_buf()
        vim.lsp.util.apply_text_edits({ edit }, buf, "utf-8")
        line_offset = line_offset + 1
      end
    end
  end
end

local task_types = {
  { task = "task_default", marker = "task_marker_default", next_text = "[-]" },
  {
    task = "task_active",
    marker = "task_marker_active",
    next_text = "[x]",
    next_cb = transition_task_active_to_done,
  },
  {
    task = "task_done",
    marker = "task_marker_done",
    next_text = "[ ]",
    next_cb = transition_task_done_to_default,
  },
  { task = "task_cancelled", marker = "task_marker_cancelled", next_text = "[ ]" },
}

local function toggle_task(node, force_clear)
  if force_clear then
    if node:type() == "task_default" then
      vim.api.nvim_exec2([[s/\v\[.\]/[_]/]], { output = false })
    else
      vim.api.nvim_exec2([[s/\v\[.\]/[ ]/]], { output = false })
    end
    return true
  end
  for _, task_node_type in ipairs(task_types) do
    if node:type() == task_node_type.task then
      local marker_node = node:child(0)
      if not marker_node then return end
      if marker_node:type() == task_node_type.marker then
        local range = slib.node_to_lsp_range(marker_node)
        local edit = { range = range, newText = task_node_type.next_text }
        local buf = vim.api.nvim_get_current_buf()
        vim.lsp.util.apply_text_edits({ edit }, buf, "utf-8")
        if task_node_type.next_cb then task_node_type.next_cb(node) end
        return true
      end
    end
  end
  return false
end

local is_task_node = function(node)
  for _, task_node_type in ipairs(task_types) do
    if node:type() == task_node_type.task then return true end
  end
  return false
end

local is_list_item_node = function(node)
  return node:type() == "list_item"
end

local is_section_node = function(node)
  return node:type() == "section"
end

local is_outline_node = function(node)
  return node:type():match("^outline_%d$") ~= nil
end

local is_code_block_node = function(node)
  return node:type() == "code_block"
end

local is_image_node = function(node)
  return node:type() == "image"
end

local is_banner_node = function(node)
  return node:type() == "banner"
end

local is_task_session_node = function(node)
  return node:type() == "task_session"
end

local is_task_schedule_node = function(node)
  return node:type() == "task_schedule"
end

local is_task_completion_node = function(node)
  return node:type() == "task_completion"
end

local is_horizontal_rule_node = function(node)
  return node:type() == "horizontal_rule"
end

local is_double_horizontal_rule_node = function(node)
  return node:type() == "double_horizontal_rule"
end

local is_label_line_node = function(node)
  return node:type() == "label_line"
end

local is_text_line_node = function(node)
  return node:type() == "text_line"
end

local movable_entry_specs = {
  { matches = is_outline_node },
  { matches = is_task_node },
  { matches = is_list_item_node },
  { matches = is_section_node },
  { matches = is_code_block_node },
  { matches = is_image_node },
  { matches = is_banner_node },
  { matches = is_task_session_node },
  { matches = is_task_schedule_node },
  { matches = is_task_completion_node },
  { matches = is_horizontal_rule_node },
  { matches = is_double_horizontal_rule_node },
  { matches = is_label_line_node },
  { matches = is_text_line_node },
}

local get_cursor_node = function()
  local root = slib.get_root()
  if root == nil then return end

  local position = vim.api.nvim_win_get_cursor(0)
  local row = position[1]
  local line_length = #vim.fn.getline(row)
  local col = math.max(line_length - 1, 0)
  return root:named_descendant_for_range(row - 1, col, row - 1, col)
end

local get_row_node = function(row)
  local root = slib.get_root()
  if root == nil then return end

  local line_length = #vim.fn.getline(row)
  local col = math.max(line_length - 1, 0)
  return root:named_descendant_for_range(row - 1, col, row - 1, col)
end

local get_node_start_row = function(node)
  return node:range()
end

local get_entry_at_row
local get_node_line_range

local get_outline_line_range = function(node)
  local start_line = get_node_start_row(node) + 1
  local end_line = start_line
  local current_indent = vim.fn.indent(start_line)
  local line_count = vim.api.nvim_buf_line_count(0)

  local line = start_line + 1
  while line <= line_count do
    local entry = get_entry_at_row(line)
    if entry then
      local entry_start_line = get_node_start_row(entry) + 1
      local entry_indent = vim.fn.indent(entry_start_line)
      if entry_indent <= current_indent then break end

      local _, entry_end_line = get_node_line_range(entry)
      end_line = math.max(end_line, entry_end_line)
      line = entry_end_line + 1
    else
      local text = vim.fn.getline(line)
      if text == "" then
        local next_line = line + 1
        while next_line <= line_count and vim.fn.getline(next_line) == "" do
          next_line = next_line + 1
        end

        if next_line > line_count then break end

        local next_entry = get_entry_at_row(next_line)
        if next_entry then
          local next_entry_start_line = get_node_start_row(next_entry) + 1
          if vim.fn.indent(next_entry_start_line) <= current_indent then break end
        else
          if vim.fn.indent(next_line) <= current_indent then break end
        end

        end_line = next_line - 1
        line = next_line
      else
        if vim.fn.indent(line) <= current_indent then break end
        end_line = line
        line = line + 1
      end
    end
  end

  return start_line, end_line
end

local is_movable_entry = function(node)
  for _, entry_spec in ipairs(movable_entry_specs) do
    if entry_spec.matches(node) then return true end
  end
  return false
end

get_entry_at_row = function(row)
  local current_row = row - 1
  local node = get_row_node(row)
  local row_nodes = {}
  while node do
    if get_node_start_row(node) ~= current_row then break end
    table.insert(row_nodes, node)
    node = node:parent()
  end

  for _, entry_spec in ipairs(movable_entry_specs) do
    for _, row_node in ipairs(row_nodes) do
      if entry_spec.matches(row_node) then return row_node end
    end
  end
end

local get_current_entry = function()
  return get_entry_at_row(vim.api.nvim_win_get_cursor(0)[1])
end

get_node_line_range = function(node)
  if is_outline_node(node) then return get_outline_line_range(node) end

  local start_row, _, end_row, end_col = node:range()
  local end_line = end_row + 1
  if end_col == 0 and end_row > start_row then end_line = end_line - 1 end
  return start_row + 1, end_line
end

local get_semantic_parent = function(entry)
  local entry_start_line = get_node_start_row(entry) + 1
  local entry_indent = vim.fn.indent(entry_start_line)
  local parent = entry:parent()
  if not parent then return end

  while parent and parent:type() ~= "document" do
    local parent_start_line = get_node_start_row(parent) + 1
    if not is_outline_node(parent) then break end
    if vim.fn.indent(parent_start_line) < entry_indent then break end
    parent = parent:parent()
  end

  return parent
end

local get_sibling_entries = function(entry)
  local parent = get_semantic_parent(entry)
  if not parent then return end

  local entries = {}
  local current_index = nil
  local entry_start_line = get_node_start_row(entry) + 1
  local entry_start_row, _, entry_end_row, entry_end_col = entry:range()
  local entry_indent = vim.fn.indent(entry_start_line)
  local is_document_parent = parent:type() == "document"
  local parent_start_line, parent_end_line = 1, vim.api.nvim_buf_line_count(0)

  if not is_document_parent then
    parent_start_line, parent_end_line = get_node_line_range(parent)
    parent_start_line = parent_start_line + 1
  end

  local seen = {}
  for line = parent_start_line, parent_end_line do
    if vim.fn.getline(line) ~= "" and vim.fn.indent(line) == entry_indent then
      local sibling = get_entry_at_row(line)
      if sibling then
        local sibling_start_line = get_node_start_row(sibling) + 1
        if sibling_start_line == line then
          local sibling_key = string.format("%d:%s", sibling_start_line, sibling:type())
          if not seen[sibling_key] then
            seen[sibling_key] = true
            table.insert(entries, sibling)
            local child_start_row, _, child_end_row, child_end_col = sibling:range()
            if
              child_start_row == entry_start_row
              and child_end_row == entry_end_row
              and child_end_col == entry_end_col
              and sibling:type() == entry:type()
            then
              current_index = #entries
            end
          end
        end
      end
    end
  end

  return entries, current_index
end

local get_entry_family = function(node)
  if is_outline_node(node) then return "outline" end
  if is_task_node(node) then return "task" end
  if is_list_item_node(node) then return "list" end
  if is_section_node(node) then return "section" end
  return "other"
end

local get_entry_line_step_bounds = function(entry)
  local parent = get_semantic_parent(entry)
  local line_count = vim.api.nvim_buf_line_count(0)
  if not parent or parent:type() == "document" then return 1, line_count end

  local parent_start_line, parent_end_line = get_node_line_range(parent)
  return parent_start_line + 1, parent_end_line
end

local should_structurally_swap = function(entry, sibling_entry, direction)
  if not sibling_entry then return false end

  local entry_family = get_entry_family(entry)
  if entry_family == "other" or entry_family ~= get_entry_family(sibling_entry) then return false end

  local start_line, end_line = get_node_line_range(entry)
  local sibling_start_line, sibling_end_line = get_node_line_range(sibling_entry)
  if direction == "up" then return sibling_end_line == start_line - 1 end
  return sibling_start_line == end_line + 1
end

local move_entry_by_line = function(start_line, end_line, direction, min_line, max_line)
  if direction == "up" then
    if start_line <= min_line then return false end
    vim.cmd(string.format("silent keepjumps %d,%dmove %d", start_line, end_line, start_line - 2))
    return start_line - 1
  end

  if end_line >= max_line then return false end
  vim.cmd(string.format("silent keepjumps %d,%dmove %d", start_line, end_line, end_line + 1))
  return start_line + 1
end

local move_current_entry = function(direction)
  local entry = get_current_entry()
  if not entry then return nil end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local start_line, end_line = get_node_line_range(entry)
  local entries, current_index = get_sibling_entries(entry)
  local sibling_entry = nil
  if entries and current_index then
    local target_index = direction == "up" and current_index - 1 or current_index + 1
    sibling_entry = entries[target_index]
  end

  if not should_structurally_swap(entry, sibling_entry, direction) then
    local min_line, max_line = get_entry_line_step_bounds(entry)
    local moved_start_line = move_entry_by_line(start_line, end_line, direction, min_line, max_line)
    if moved_start_line == false then return false end

    local target_line = vim.fn.getline(moved_start_line)
    vim.api.nvim_win_set_cursor(0, { moved_start_line, math.min(cursor[2], #target_line) })
    return true
  end

  local target_start_line, target_end_line = get_node_line_range(sibling_entry)

  if direction == "up" then
    vim.cmd(string.format("silent keepjumps %d,%dmove %d", start_line, end_line, target_start_line - 1))
    start_line = target_start_line
  else
    vim.cmd(string.format("silent keepjumps %d,%dmove %d", start_line, end_line, target_end_line))
    start_line = target_end_line - (end_line - start_line)
  end

  local target_line = vim.fn.getline(start_line)
  vim.api.nvim_win_set_cursor(0, { start_line, math.min(cursor[2], #target_line) })
  return true
end

local move_current_entry_with_count = function(direction)
  for _ = 2, vim.v.count1 do
    local result = move_current_entry(direction)
    if result ~= true then return end
  end
end

local move_current_entry_or_noop = function(direction)
  local result = move_current_entry(direction)
  if result ~= true then return end
  move_current_entry_with_count(direction)
end

local move_current_entry_or_noop_insert = function(direction)
  vim.cmd("stopinsert")
  move_current_entry_or_noop(direction)
  vim.cmd("startinsert")
end

local handle_toggle_task = function(force_clear)
  local position = vim.api.nvim_win_get_cursor(0)
  local line_length = #vim.fn.getline(position[1])
  local node = get_cursor_node()
  if not node and line_length == 0 then return end

  -- toggle task nodes or parent task nodes if called on a session node
  while node do
    local node_line = node:range()
    if node_line ~= position[1] - 1 then break end
    local target = node
    if node:type() == "task_session" then
      local parent_task_node = node:parent()
      if parent_task_node then target = parent_task_node end
    end

    -- hacky but we're always on the task here
    if is_task_node(target) then
      if toggle_task(target, force_clear) then return end
    end

    node = node:parent()
  end

  -- no task node found, create one
  if force_clear then return end
  local view = vim.fn.winsaveview()
  vim.api.nvim_exec2("s/\\v\\zs\\S\\ze/[ ] \\0/g", { output = true }) -- .* -> [ ] \0
  vim.cmd("nohl")
  vim.fn.winrestview(view)
end

local handle_set_schedule = function()
  vim.ui.input({ prompt = "Schedule: " }, function(input)
    if not input or input == "" then return end
    local date = lib.node.chrono.to_schedule(input)
    if type(date) ~= "string" then return end

    local position = vim.api.nvim_win_get_cursor(0)
    local node = get_cursor_node()
    if not node and #vim.fn.getline(position[1]) == 0 then return end

    while node do
      local node_line = node:range()
      if node_line ~= position[1] - 1 then break end
      local target = node

      local schedule_text = "Schedule: " .. date .. "\n"

      -- edit existing schedule
      if node:type() == "task_schedule" then
        -- set the text of the whole session node
        local range = slib.node_to_lsp_range(node)
        local edit = { range = range, newText = schedule_text }
        local buf = vim.api.nvim_get_current_buf()
        vim.lsp.util.apply_text_edits({ edit }, buf, "utf-8")
      end

      -- add new schedule after all the schedules and sessions and before anything else
      if is_task_node(target) then
        local last_pre_node = target:child(0)
        local task_row = target:range()

        for curr in target:iter_children() do
          local curr_row = curr:range()
          if curr_row == task_row then goto continue end

          if curr:type() == "task_schedule" or curr:type() == "task_session" then
            last_pre_node = curr
          else
            break
          end

          ::continue::
        end

        local row = last_pre_node:range()

        local indent = vim.fn.indent(row + 1) + (last_pre_node == target:child(0) and vim.bo.tabstop or 0)
        schedule_text = string.rep(" ", indent) .. schedule_text

        local range = {
          start = { line = row + 1, character = 0 },
          ["end"] = { line = row + 1, character = 0 },
        }
        local edit = { range = range, newText = schedule_text }
        local buf = vim.api.nvim_get_current_buf()
        vim.lsp.util.apply_text_edits({ edit }, buf, "utf-8")
      end

      node = node:parent()
    end
  end)
end

local handle_cr = function()
  local root = slib.get_root()
  if root == nil then return end

  local position = vim.api.nvim_win_get_cursor(0)
  local node = root:named_descendant_for_range(position[1] - 1, position[2], position[1] - 1, position[2])
  if not node then return end

  -- external link
  if node:type() == "external_link" then
    local url = vim.treesitter.get_node_text(node, 0)
    lib.shell.open(url)
    return
  end

  -- internal link
  local internal_link = lib.ts.find_parent(node, "internal_link")
  if internal_link then
    local target = lib.ts.find_child(internal_link, "internal_link_target", true)
    if not target then return end
    local target_text = vim.treesitter.get_node_text(target, 0)
    if not target_text then return end

    -- node name transforms
    target_text = string.gsub(target_text, "%s+", "-")
    target_text = string.lower(target_text)

    local command =
      string.format("WIKI_ROOT=$HOME/brain/wiki TASK_ROOT=$HOME/brain/wiki core wiki resolve '%s'", target_text)
    local path = lib.shell.exec(command)
    vim.cmd(string.format("e %s", vim.fn.fnameescape(path)))

    return
  end

  -- fallback: if there's a single link on the line, open it
  local leftmost_node = node
  while leftmost_node:parent() do
    local parent = leftmost_node:parent()
    if not parent then break end
    if parent:range() ~= node:range() then break end
    leftmost_node = parent
  end
  local leftmost_internal_links = lib.ts.find_children(leftmost_node, "internal_link", true)
  if #leftmost_internal_links == 1 then
    local leftmost_internal_link = leftmost_internal_links[1]
    local target = lib.ts.find_child(leftmost_internal_link, "internal_link_target", true)
    if not target then return end
    local target_text = vim.treesitter.get_node_text(target, 0)
    if not target_text then return end

    -- node name transforms
    target_text = string.gsub(target_text, "%s+", "-")
    target_text = string.lower(target_text)

    local command =
      string.format("WIKI_ROOT=$HOME/brain/wiki TASK_ROOT=$HOME/brain/wiki core wiki resolve '%s'", target_text)
    local path = lib.shell.exec(command)
    vim.cmd(string.format("e %s", vim.fn.fnameescape(path)))

    return
  end
  local external_links = lib.ts.find_children(leftmost_node, "external_link", true)
  if #external_links == 1 then
    local external_link = external_links[1]
    local url = vim.treesitter.get_node_text(external_link, 0)
    lib.shell.open(url)
    return
  end
end

local setup_mappings = function()
  vim.keymap.set("n", "<c-space>", handle_toggle_task, { buffer = true, noremap = true })
  vim.keymap.set("n", "<c-c>", function()
    handle_toggle_task(true)
  end, { buffer = true, noremap = true })
  vim.keymap.set("n", "<leader>es", handle_set_schedule, { buffer = true, noremap = true })
  vim.keymap.set("n", "<cr>", handle_cr, { buffer = true, noremap = true })
  vim.keymap.set("n", "<a-k>", function()
    move_current_entry_or_noop("up")
  end, { buffer = true, noremap = true })
  vim.keymap.set("n", "<a-j>", function()
    move_current_entry_or_noop("down")
  end, { buffer = true, noremap = true })
  vim.keymap.set("i", "<a-k>", function()
    move_current_entry_or_noop_insert("up")
  end, { buffer = true, noremap = true })
  vim.keymap.set("i", "<a-j>", function()
    move_current_entry_or_noop_insert("down")
  end, { buffer = true, noremap = true })
  -- vim.keymap.set("n", ">", handle_indent, { buffer = true })
  -- vim.keymap.set("n", "<", handle_dedent, { buffer = true })
  -- vim.keymap.set("n", "zR", handle_expand_all, { buffer = true, noremap = true })
  -- vim.keymap.set("n", "zM", handle_collapse_all, { buffer = true, noremap = true })
end

local function fold_tasks()
  local view = vim.fn.winsaveview()
  local root = slib.get_root()
  if root == nil then return end

  local task_node_types = {
    "task_default",
    "task_active",
    "task_done",
    "task_cancelled",
  }
  local task_nodes = {}
  for _, task_node_type in ipairs(task_node_types) do
    local nodes = lib.ts.find_children(root, task_node_type, true)
    for _, node in ipairs(nodes) do
      table.insert(task_nodes, node)
    end
  end

  for _, node in ipairs(task_nodes) do
    local row = node:range()
    local has_fold = vim.fn.foldlevel(row + 1) ~= 0
    local is_folded = vim.fn.foldclosed(row + 1) ~= -1
    local children = lib.ts.find_children(node, nil)
    local has_children = #children > 2
    if has_fold and has_children and not is_folded then
      -- how it should work: vim.api.nvim_command("silent! " .. row + 1 .. "foldclose")
      -- but both this and "<range>foldd zc" will make neovim crash with "corrupted doubly-linked list"
      -- so we'll do it the dumb way
      vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
      vim.api.nvim_command("normal! zc")
    end
  end

  -- also fold first line if we have meta
  local meta = slib.get_document_meta()
  if meta then
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_command("normal! zc")
  end

  vim.fn.winrestview(view)
end

local setup = function()
  if vim.bo.filetype ~= "syslang" then return end
  if vim.b.slang_loaded then return end
  vim.b.slang_loaded = true

  setup_options()
  pcall(vim.treesitter.start, 0, "syslang")
  setup_mappings()
  folding.setup()

  local view = vim.fn.winsaveview()
  pcall(fold_tasks)
  vim.fn.winrestview(view)

  do
    local ok, title = pcall(slib.get_document_title)
    if ok and title then vim.opt_local.winbar = title end
  end
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = 0,
    callback = function()
      -- vim.opt_local.winbar = slib.get_document_title()
      -- with pcall
      local ok, title = pcall(slib.get_document_title)
      if ok then vim.opt_local.winbar = title end
    end,
  })

  -- TODO: top gutter attempt with extmarks
  -- local bufnr = vim.api.nvim_get_current_buf()
  -- local namespace = vim.api.nvim_create_namespace("syslang")
  -- vim.api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
  --   -- end_row = 1,
  --   virt_lines = { { { " " } }, { { " " } } },
  --   -- virt_lines_above = true,
  --   virt_text_pos = "inline",
  --   right_gravity = false,
  -- })

  -- fallback for now: ensure there's a newline at the top of the file
  -- vim.schedule(function()
  --   local needs_newline = not (vim.fn.getline(1) == "" or string.match(vim.fn.getline(1), "^@meta"))
  --   if needs_newline then
  --     local view = vim.fn.winsaveview()
  --     vim.api.nvim_buf_set_lines(0, 0, 0, false, { "" })
  --     vim.fn.winrestview(view)
  --   end
  -- end)
end

return {
  render_statuscolumn = _G.SyslangStatuscolumn,
  setup = setup,
}

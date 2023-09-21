local ts_utils = require("nvim-treesitter.ts_utils")
local folding = require("syslang/folding")

local task_was_just_completed_and_moved = false

local setup_options = function()
  vim.opt_local.foldlevel = 999
  vim.opt_local.wrap = false
  vim.opt_local.signcolumn = "yes:1"
  vim.opt_local.number = false
  vim.opt_local.breakindent = true
  vim.opt_local.linebreak = true
  vim.opt_local.cursorlineopt = "screenline"
  vim.opt_local.winbar = " "
  vim.opt_local.commentstring = "-- %s"
  vim.opt_local.textwidth = 100
  vim.opt_local.breakindentopt = "list:-1"
  vim.opt_local.formatlistpat = [[ ^\s*(\d)\+\s* ]]
  vim.opt_local.formatoptions = "cqrt"
  vim.opt_local.cinwords = "*,-"
  vim.opt_local.smartindent = true
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
    vim.lsp.util.apply_text_edits({ edit }, 0, "utf-8")
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
        local range = ts_utils.node_to_lsp_range(datetime_node)
        local text = string.format("%s %s - %s %s", start_date, start_time, end_date, end_time)
        if start_date == end_date then text = string.format("%s %s-%s", start_date, start_time, end_time) end
        local edit = { range = range, newText = text }
        vim.lsp.util.apply_text_edits({ edit }, 0, "utf-8")
      end
    end
  end

  -- tree-sitter has a bug where it returns the child as its own parent
  local parent = task_node:parent()
  local child_row = task_node:range()
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

  -- move the task under the previous done task on the same level or as the first task
  for i = 0, num_children - 1 do
    local current_child = parent:named_child(i)
    if not current_child then return end
    local curren_child_row = current_child:range()
    -- can't compare by reference here, by row is good enough
    if curren_child_row == child_row then
      index_of_task = i
      break
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

  -- check index and
  if not index_of_task then return error("index_of_task is nil") end

  -- bail if first or preceded by a done task and auto-fold
  if last_done_task_index == index_of_task - 1 or (last_done_task_index == nil and first_task_index == nil) then
    --   local row = task_node:range() + 1
    --   delayed_fold_close(row)
    return
  end

  -- get target
  local target_index = math.max(last_done_task_index or 0, first_task_index or 0)
  if not target_index then return end
  local target_node = parent:named_child(target_index)
  if not target_node then return end

  local start_row, _, end_row = task_node:range()
  local target_start_row = target_node:range()
  if start_row < target_start_row then target_start_row = target_start_row + 1 end

  vim.cmd(string.format("%d,%dm%d", start_row + 1, end_row, target_start_row))

  vim.schedule(function()
    task_was_just_completed_and_moved = true
  end)

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
        local range = ts_utils.node_to_lsp_range(session_node)
        range.start.line = range.start.line - line_offset
        range.start.character = 0
        range["end"].line = range["end"].line + 1 - line_offset
        range["end"].character = 0
        local edit = { range = range, newText = "" }
        vim.lsp.util.apply_text_edits({ edit }, 0, "utf-8")
        line_offset = line_offset + 1
      end
    end
  end
end

local transition_task_active_to_default = function(task_node)
  local marker_node = task_node:child(0)
  if not marker_node then return end
  local range = ts_utils.node_to_lsp_range(marker_node)
  local edit = { range = range, newText = "[ ]" }
  vim.lsp.util.apply_text_edits({ edit }, 0, "utf-8")
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

local function toggle_task(node)
  for _, task_node_type in ipairs(task_types) do
    if node:type() == task_node_type.task then
      local marker_node = node:child(0)
      if not marker_node then return end
      if marker_node:type() == task_node_type.marker then
        local range = ts_utils.node_to_lsp_range(marker_node)
        local edit = { range = range, newText = task_node_type.next_text }
        vim.lsp.util.apply_text_edits({ edit }, 0, "utf-8")
        if task_node_type.next_cb then task_node_type.next_cb(node) end
        return true
      end
    end
  end
  return false
end

-- local function get_new_node(old_node)
--   local parser = vim.treesitter.get_parser()
--   local root = parser:parse()[1]:root()
--
--   local start_line, start_col, end_line, end_col = old_node:range()
--   return root:named_descendant_for_range(start_line, start_col, end_line, end_col)
-- end
--
local is_task_node = function(node)
  for _, task_node_type in ipairs(task_types) do
    if node:type() == task_node_type.task then return true end
  end
  return false
end

local find_parent_task_node = function(node)
  local parent = node:parent()
  while parent do
    if is_task_node(parent) then return parent end
    parent = parent:parent()
  end
  return nil
end

local handle_toggle_task = function()
  local parser = vim.treesitter.get_parser()
  local root = parser:parse()[1]:root()

  local position = vim.api.nvim_win_get_cursor(0)
  local line_length = #vim.fn.getline(position[1])
  local node = root:named_descendant_for_range(position[1] - 1, line_length - 1, position[1] - 1, line_length - 1)

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
      if task_was_just_completed_and_moved then
        task_was_just_completed_and_moved = false

        vim.cmd("undo")

        local post_undo_position = vim.api.nvim_win_get_cursor(0)
        local post_line_length = #vim.fn.getline(post_undo_position[1])

        local new_root = vim.treesitter.get_parser():parse()[1]:root()
        local node_at_range = new_root:named_descendant_for_range(
          post_undo_position[1] - 1,
          post_line_length - 1,
          post_undo_position[1] - 1,
          post_line_length - 1
        )
        local updated_target = is_task_node(node_at_range) and node_at_range or find_parent_task_node(node_at_range)
        if not updated_target then error("updated_target is nil") end

        transition_task_active_to_default(updated_target)
        return
      end

      if toggle_task(target) then return end
    end

    node = node:parent()
  end

  -- no task node found, create one
  local view = vim.fn.winsaveview()
  vim.api.nvim_exec2("s/\\v\\zs\\S\\ze/[ ] \\0/g", { output = true }) -- .* -> [ ] \0
  vim.cmd("nohl")
  vim.fn.winrestview(view)
end

local setup_mappings = function()
  vim.keymap.set("n", "<c-space>", handle_toggle_task, { buffer = true, noremap = true })
  -- vim.keymap.set("n", ">", handle_indent, { buffer = true })
  -- vim.keymap.set("n", "<", handle_dedent, { buffer = true })
  -- vim.keymap.set("n", "zR", handle_expand_all, { buffer = true, noremap = true })
  -- vim.keymap.set("n", "zM", handle_collapse_all, { buffer = true, noremap = true })
end

local function fold_tasks()
  local view = vim.fn.winsaveview()
  local parser = vim.treesitter.get_parser()
  local root = parser:parse()[1]:root()

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
    if has_fold and has_children and not is_folded then vim.api.nvim_command("silent! " .. row + 1 .. "foldclose") end
  end
  vim.fn.winrestview(view)
end

local setup = function()
  if vim.b.slang_loaded then return end
  vim.b.slang_loaded = true

  setup_options()
  setup_mappings()
  folding.setup()

  vim.schedule_wrap(function()
    fold_tasks()
  end)()

  local group = vim.api.nvim_create_augroup("SyslangFoldPersistence", { clear = true })
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_create_autocmd({ "CursorMoved" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      task_was_just_completed_and_moved = false
    end,
  })
end

return {
  setup = setup,
}

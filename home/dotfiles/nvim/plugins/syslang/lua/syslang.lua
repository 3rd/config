local syntax = require("syslang/syntax")
local folding = require("syslang/folding")

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

-- local handle_toggle_task = function()
--   local view = vim.fn.winsaveview()
--   local line = vim.fn.getline(".")
--   if vim.fn.match(line, "\\v\\[\\s\\]") >= 0 then -- [ ] -> [-]
--     vim.api.nvim_exec2("s/\\v\\[\\zs\\s\\ze\\]/-/g", { output = true })
--   elseif vim.fn.match(line, "\\v\\[-\\]") >= 0 then -- [-] -> [x]
--     vim.api.nvim_exec2("s/\\v\\[\\zs-\\ze\\]/x/g", { output = true })
--   elseif vim.fn.match(line, "\\v\\[(✔|x|X)\\]") >= 0 then -- [x] -> [ ]
--     vim.api.nvim_exec2("s/\\v\\[\\zs(✔|x|X)\\ze\\]/ /g", { output = true })
--   else
--     vim.api.nvim_exec2("s/\\v\\zs\\S\\ze/[ ] \\0/g", { output = true }) -- .* -> [ ] \0
--   end
--   vim.cmd("nohl")
--   vim.fn.winrestview(view)
-- end

local handle_toggle_task = function()
  local ts_utils = require("nvim-treesitter.ts_utils")
  local parser = vim.treesitter.get_parser()
  local root = parser:parse()[1]:root()

  local position = vim.api.nvim_win_get_cursor(0)
  local line_length = #vim.fn.getline(position[1])
  local node = root:named_descendant_for_range(position[1] - 1, line_length - 1, position[1] - 1, line_length - 1)

  local task_types = {
    { task = "task_default", marker = "task_marker_default", next_text = "[-]" },
    {
      task = "task_active",
      marker = "task_marker_active",
      next_text = "[x]",
      --- @param task_node TSNode
      next_cb = function(task_node)
        local task_text_node = task_node:child(1)
        local _, _, task_end_row, task_end_col = task_text_node:range()

        local indent = vim.fn.indent(vim.fn.line("."))
        local sessions = lib.ts.find_children(task_node, "task_session")
        local active_sessions = {}

        -- active session have a single (time) node
        for _, session_node in ipairs(sessions) do
          local time_nodes = lib.ts.find_children(session_node, "time", true)
          if #time_nodes == 1 then table.insert(active_sessions, session_node) end
        end

        -- if there are no sessions, create an instant one
        if #sessions == 0 then
          local session_text = "Session: " .. os.date("%Y.%m.%d %H:%M-%H:%M") .. "\n"
          session_text = string.rep(" ", indent + vim.bo.tabstop) .. session_text
          local range = {
            start = { line = task_end_row, character = task_end_col },
            ["end"] = { line = task_end_row, character = task_end_col },
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
      end,
    },
    {
      task = "task_done",
      marker = "task_marker_done",
      next_text = "[ ]",
      next_cb = function(task_node)
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
      end,
    },
    { task = "task_cancelled", marker = "task_marker_cancelled", next_text = "[ ]" },
  }

  while node ~= nil do
    local node_line = node:range()
    if node_line ~= position[1] - 1 then
      -- log("break", node_line, position[1] - 1)
      break
    end
    for _, task_node_type in ipairs(task_types) do
      if node:type() == task_node_type.task then
        local marker_node = node:child(0)
        if marker_node:type() == task_node_type.marker then -- overkill
          local range = ts_utils.node_to_lsp_range(marker_node)
          local edit = { range = range, newText = task_node_type.next_text }
          vim.lsp.util.apply_text_edits({ edit }, 0, "utf-8")
          if task_node_type.next_cb ~= nil then task_node_type.next_cb(node) end
          return
        end
      end
    end
    node = node:parent()
  end

  -- no task node found, create one
  local view = vim.fn.winsaveview()
  vim.api.nvim_exec2("s/\\v\\zs\\S\\ze/[ ] \\0/g", { output = true }) -- .* -> [ ] \0
  vim.cmd("nohl")
  vim.fn.winrestview(view)
end

local heading_node_types = { "heading_1", "heading_2", "heading_3", "heading_4", "heading_5", "heading_6" }

-- TODO: indent subheadings, dedent
local handle_indent = function()
  local ts_utils = require("nvim-treesitter.ts_utils")
  local heading_node = lib.ts.find_parent_at_line(heading_node_types)
  if heading_node ~= nil then
    local heading_level = heading_node:type():match("%d")
    local heading_node_range = ts_utils.node_to_lsp_range(heading_node)

    local heading_text_node = lib.ts.find_child(heading_node, "text_to_eol")
    if heading_text_node == nil then throw("no text node found") end
    local heading_text = vim.treesitter.get_node_text(heading_text_node, 0)
    local heading_text_range = ts_utils.node_to_lsp_range(heading_text_node)

    local newIndent = string.rep("  ", heading_level)
    local newMarker = string.rep("*", heading_level + 1)
    local newText = newIndent .. newMarker .. " " .. heading_text
    local row = vim.fn.line(".") - 1

    -- adjust indent for all child lines
    local children_lines = string.split(vim.treesitter.get_node_text(heading_node, 0), "\n")
    if #children_lines > 1 then
      -- log("children_lines", children_lines)
      local newLines = {}
      -- skip first and regulate indent for all other lines
      -- local previousChildIndent = string.rep("  ", heading_level)
      -- local newChildIndent = string.rep("  ", heading_level + 1)
      for i = 2, #children_lines do
        local childLine = children_lines[i]
        -- if childLine:match("^" .. previousChildIndent) then
        --   childLine = childLine:gsub("^" .. previousChildIndent, "")
        -- end
        -- childLine = newChildIndent .. childLine
        childLine = "  " .. childLine
        table.insert(newLines, childLine)
      end
      local newChildrenText = table.concat(newLines, "\n")
      -- log("children", {
      --   previousIndent = previousChildIndent,
      --   newIndent = newChildIndent,
      --   lines = newLines,
      -- })

      local edit = {
        range = {
          start = { line = row + 1, character = 0 },
          ["end"] = { line = heading_node_range["end"].line, character = heading_node_range["end"].character },
        },
        newText = newChildrenText,
      }
      vim.lsp.util.apply_text_edits({ edit }, 0, "utf-8")
    end

    -- replace heading text
    -- log("replace heading text", newText)
    local edit = {
      range = {
        start = { line = row, character = 0 },
        ["end"] = { line = heading_node_range.start.line, character = heading_text_range["end"].character },
      },
      newText = newText,
    }
    vim.lsp.util.apply_text_edits({ edit }, 0, "utf-8")

    return
  end

  -- fallback to default indent
  vim.cmd("normal! >>")
end

local handle_dedent = function()
  log("dedent")

  -- fallback to default dedent
  vim.cmd("normal! <<")
end

local function link(from, to)
  if type(to) == "string" then
    local group = "@slang." .. from
    group = group:gsub("._$", "")
    -- log("linking " .. group .. " to " .. to)
    vim.cmd("hi! link " .. group .. " " .. to)
  else
    for k, v in pairs(to) do
      link(from .. "." .. k, v)
    end
  end
end

local link_highlights = function()
  local links = {
    error = "Error",
    document = {
      title = "Question",
      meta = {
        _ = "Question",
        field = {
          _ = "String",
          key = "Identifier",
          value = "String",
        },
      },
    },
    bold = "ModeMsg",
    italic = "Italic",
    underline = "Underlined",
    comment = "Comment",
    string = "String",
    number = "Number",
    ticket = "Blue",
    time = "SpecialChar",
    timerange = "SpecialChar",
    date = "SpecialChar",
    daterange = "SpecialChar",
    datetime = "SpecialChar",
    datetimerange = "SpecialChar",
    heading_1 = {
      marker = "Title",
      text = "Title",
    },
    heading_2 = {
      marker = "Title",
      text = "Title",
    },
    heading_3 = {
      marker = "Title",
      text = "Title",
    },
    heading_4 = {
      marker = "Title",
      text = "Title",
    },
    heading_5 = {
      marker = "Title",
      text = "Title",
    },
    heading_6 = {
      marker = "Title",
      text = "Title",
    },
    section = "Type",
    task_default = "Normal",
    task_active = "CyanItalic",
    task_done = "Comment",
    task_cancelled = "Red",
    task_session = "Comment",
    task_schedule = "Comment",
    tag = {
      hash = "Cyan",
      positive = "Green",
      negative = "Red",
      context = "Yellow",
      danger = "TSDanger",
      identifier = "Identifier",
    },
    link = "HintText",
    external_link = "HintText",
    inline_code = "Macro",
    code_block_start = "Comment",
    code_block_language = "Comment",
    code_block_fence = "Comment",
    code_block_content = "PreProc",
    code_block_end = "Comment",
    label = "CyanItalic",
    list_item = "Normal",
    list_item_marker = "Comment",
    list_item_label = "Cyan",
    list_item_label_marker = "Comment",
  }

  for k, v in pairs(links) do
    link(k, v)
  end

  vim.cmd("hi! Bold gui=bold")
  vim.cmd("hi! Italic gui=italic")
  vim.cmd("hi! Underlined gui=underline")
end

local setup_buffer = function()
  if vim.b.slang_loaded then return end
  vim.b.slang_loaded = true

  setup_options()
  syntax.register()
  folding.register()
  -- link_highlights()

  -- mappings
  vim.keymap.set("n", "<c-space>", handle_toggle_task, { buffer = true, noremap = true })
  -- vim.keymap.set("n", ">", handle_indent, { buffer = true })
  -- vim.keymap.set("n", "<", handle_dedent, { buffer = true })
  -- vim.keymap.set("n", "zR", handle_expand_all, { buffer = true, noremap = true })
  -- vim.keymap.set("n", "zM", handle_collapse_all, { buffer = true, noremap = true })
end

return {
  setup_buffer = setup_buffer,
}

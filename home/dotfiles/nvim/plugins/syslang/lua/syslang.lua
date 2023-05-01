local syntax = require("syslang/syntax")
local folding = require("syslang/folding")

local setup_options = function()
  vim.opt_local.foldlevelstart = 999

  vim.opt_local.wrap = true
  vim.opt_local.signcolumn = "yes:2"
  vim.opt_local.number = false
  vim.opt_local.breakindent = true
  vim.opt_local.linebreak = true
  vim.opt_local.breakindentopt = "list:2" -- TODO move to list:-1 with formatlistpat
  vim.opt_local.cursorlineopt = "screenline"
  vim.opt_local.winbar = " "

  vim.opt_local.commentstring = "-- %s"
  vim.opt_local.textwidth = 999999
  vim.opt_local.formatlistpat = "^\\s*[\\[-]"
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

  -- local parser = vim.treesitter.get_parser()
  -- local root = parser:parse()[1]:root()
  -- local query = vim.treesitter.query.parse(parser:lang(), "(task_marker_default)")
  -- local position = vim.api.nvim_win_get_cursor(0)
  -- local node = root:named_descendant_for_range(position[1] - 1, 0, position[1] - 1, position[2])
  -- log(position[1], 0, position[1], position[2], node:type())

  local winnr = vim.fn.win_getid()
  local node = ts_utils.get_node_at_cursor(winnr, true)

  local task_types = {
    { task = "task_default", marker = "task_marker_default", next = "[-]" },
    { task = "task_active", marker = "task_marker_active", next = "[x]" },
    { task = "task_done", marker = "task_marker_done", next = "[ ]" },
    { task = "task_cancelled", marker = "task_marker_cancelled", next = "[ ]" },
  }

  while node ~= nil do
    for _, task_node_type in ipairs(task_types) do
      if node:type() == task_node_type.task then
        local marker_node = node:child(0)
        if marker_node:type() == task_node_type.marker then -- overkill
          local range = ts_utils.node_to_lsp_range(marker_node)
          local edit = { range = range, newText = task_node_type.next }
          vim.lsp.util.apply_text_edits({ edit }, 0, "utf-8")
          return
        end
      end
    end
    node = node:parent()
  end
end

local handle_expand_all = function()
  -- vim.opt.foldlevel = 999
  require("ufo").openAllFolds()
  -- vim.cmd("w")
end
local handle_collapse_all = function()
  -- vim.opt.foldlevel = 999
  -- require("ufo").openAllFolds()
  -- vim.cmd("w")
  require("ufo").closeAllFolds()
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
  vim.keymap.set("n", "zR", handle_expand_all, { buffer = true, noremap = true })
  vim.keymap.set("n", "zM", handle_collapse_all, { buffer = true, noremap = true })
  -- vim.keymap.set("n", ">", ">><Cmd>lua require('autolist').tab()<CR>", { buffer = true })
  -- vim.keymap.set("n", "<", "<<<Cmd>lua require('autolist').detab()<CR>", { buffer = true })
end

return {
  setup_buffer = setup_buffer,
}

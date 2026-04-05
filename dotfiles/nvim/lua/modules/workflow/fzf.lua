local FFF_BORDER_STYLE = "single"
local get_fff_reserved_bottom_rows = function()
  local reserved = vim.o.cmdheight

  if vim.o.laststatus ~= 0 then reserved = reserved + 1 end

  return reserved
end

local get_fff_bottom_half_ratio = function(_, lines)
  local reserved = get_fff_reserved_bottom_rows()
  local usable_lines = math.max(1, lines - reserved)
  return math.min(1, (usable_lines * 0.5) / lines)
end

local FFF_LAYOUT = {
  height = get_fff_bottom_half_ratio,
  width = 1,
  row = get_fff_bottom_half_ratio,
  prompt_position = "bottom",
  preview_position = "right",
  preview_size = 0.4,
  flex = false,
  show_scrollbar = true,
  path_shorten_strategy = "middle_number",
}
-- local SEARCH_PROMPT = "› "
local SEARCH_PROMPT = "🔎 "

local FFF_LIST_BORDER = { " ", "─", " ", "│", " ", "", "", "" }
local FFF_INPUT_BORDER = { " ", "─", " ", "", "", "", "", "" }
local FFF_PREVIEW_BORDER = { " ", "─", " ", "", "", "", "", "" }
local FFF_GREP_SEPARATOR = "  "
local LAST_PICKER_BACKEND = nil
local LAST_FFF_SESSION = nil
local FFF_STICKY_CWD = nil
local fff_query_has_uppercase
local maybe_sync_fff_grep_mode
local find_files
local live_grep
local live_grep_selection
local buffers
local buffer_lines
local lines
local lsp_references
local lsp_workspace_symbols

local read_file = function(path)
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then return nil end

  local stat = vim.uv.fs_fstat(fd)
  if not stat then
    vim.uv.fs_close(fd)
    return nil
  end

  local content = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  return content
end

local is_nixos = function()
  if vim.uv.fs_stat("/etc/NIXOS") ~= nil then return true end

  local os_release = read_file("/etc/os-release")
  if not os_release then return false end

  return os_release:match("^ID=nixos\n") ~= nil or os_release:match("\nID=nixos\n") ~= nil
end

local get_fff_build = function()
  if is_nixos() then return "nix run .#release" end
  return function()
    require("fff.download").download_or_build_binary()
  end
end

local set_last_picker_backend = function(backend)
  LAST_PICKER_BACKEND = backend
end

local get_fff_item_key = function(item, mode)
  if not item then return nil end

  if mode == "grep" then return string.format("%s:%d:%d", item.path or "", item.line_number or 0, item.col or 0) end

  return item.path
end

local get_fff_session_cwd = function(state)
  local ok, config = pcall(require, "fff.conf")
  if ok and config.get then
    local current = config.get()
    if current and current.base_path then return current.base_path end
  end

  if state and state.config and state.config.cwd then
    return vim.fn.fnamemodify(vim.fn.expand(state.config.cwd), ":p")
  end

  return vim.uv.cwd()
end

local capture_fff_session = function(picker_ui)
  local state = picker_ui.state
  if not state or not state.active then return end

  local current_item = state.filtered_items and state.filtered_items[state.cursor] or nil

  LAST_FFF_SESSION = {
    mode = state.mode,
    query = state.query,
    cwd = get_fff_session_cwd(state),
    title = state.config and state.config.title or nil,
    grep = vim.deepcopy(state.grep_config or (state.config and state.config.grep) or {}),
    grep_mode = state.grep_mode,
    cursor = state.cursor,
    item_key = get_fff_item_key(current_item, state.mode),
  }
end

local restore_fff_cursor = function(picker_ui, session)
  local items = picker_ui.state.filtered_items or {}
  if #items == 0 then return end

  local target_index = nil
  if session.item_key then
    for index, item in ipairs(items) do
      if get_fff_item_key(item, picker_ui.state.mode) == session.item_key then
        target_index = index
        break
      end
    end
  end

  if not target_index then target_index = math.min(session.cursor or 1, #items) end
  if target_index < 1 then return end

  picker_ui.state.cursor = target_index
  picker_ui.render_list()
  picker_ui.update_preview()
  picker_ui.update_status()
end

local resume_fff_session = function()
  if not LAST_FFF_SESSION then return false end

  local session = vim.deepcopy(LAST_FFF_SESSION)
  local fff = require("fff")

  set_last_picker_backend("fff")

  if session.mode == "grep" then
    fff.live_grep({
      cwd = session.cwd,
      title = session.title or "Live Grep",
      query = session.query,
      grep = session.grep,
    })
  else
    fff.find_files({
      cwd = session.cwd,
      title = session.title or "Files",
      query = session.query,
    })
  end

  vim.schedule(function()
    local picker_ui = require("fff.picker_ui")
    if not picker_ui.state.active then return end

    if session.mode == "grep" and session.grep_mode and picker_ui.state.grep_mode ~= session.grep_mode then
      picker_ui.state.grep_mode = session.grep_mode
      picker_ui.update_results_sync()
    end

    restore_fff_cursor(picker_ui, session)
  end)

  return true
end

local resume_last_picker = function()
  if LAST_PICKER_BACKEND == "fff" and resume_fff_session() then return end

  set_last_picker_backend("fzf_lua")
  require("fzf-lua").resume()
end

local truncate_display_text = function(text, available)
  if available <= 0 then return "" end
  if vim.fn.strdisplaywidth(text) <= available then return text end
  if available <= 3 then return "…" end

  local nchars = vim.fn.strchars(text)
  local lo, hi = 0, nchars

  while lo < hi do
    local mid = math.floor((lo + hi + 1) / 2)
    if vim.fn.strdisplaywidth(vim.fn.strcharpart(text, 0, mid)) <= available - 1 then
      lo = mid
    else
      hi = mid - 1
    end
  end

  return vim.fn.strcharpart(text, 0, lo) .. "…"
end

local patch_fff_grep_renderer = function()
  local grep_renderer = require("fff.grep.grep_renderer")

  if grep_renderer._flat_layout_patched then return grep_renderer end

  local treesitter_highlight = require("fff.treesitter_hl")

  grep_renderer.render_line = function(item, ctx)
    local path = item.relative_path or item.path or item.name or ""
    local location = string.format(":%d:%d", item.line_number or 0, (item.col or 0) + 1)
    local prefix = path .. location
    local raw_content = item.line_content

    if type(raw_content) ~= "string" then raw_content = raw_content and tostring(raw_content) or "" end

    local available =
      math.max(0, ctx.win_width - vim.fn.strdisplaywidth(prefix) - vim.fn.strdisplaywidth(FFF_GREP_SEPARATOR) - 2)
    local content = truncate_display_text(raw_content, available)
    local line = prefix .. FFF_GREP_SEPARATOR .. content
    local padding = math.max(0, ctx.win_width - vim.fn.strdisplaywidth(line) + 5)

    item._has_group_header = false
    item._grep_path = path
    item._grep_location = location
    item._grep_content_offset = #prefix + #FFF_GREP_SEPARATOR
    item._trimmed_content = content

    return { line .. string.rep(" ", padding) }
  end

  grep_renderer.apply_highlights = function(item, ctx, item_idx, buf, ns_id, line_idx, line_content)
    local config = ctx.config
    local row = line_idx - 1
    local is_cursor = item_idx == ctx.cursor
    local path = item._grep_path or item.relative_path or item.path or item.name or ""
    local location = item._grep_location or string.format(":%d:%d", item.line_number or 0, (item.col or 0) + 1)
    local location_start = #path
    local location_end = location_start + #location
    local separator_start = location_end
    local separator_end = separator_start + #FFF_GREP_SEPARATOR
    local content_start = item._grep_content_offset or separator_end

    if is_cursor then
      vim.api.nvim_buf_set_extmark(buf, ns_id, row, 0, {
        end_col = 0,
        end_row = row + 1,
        hl_group = config.hl.cursor,
        hl_eol = true,
        priority = 100,
      })
    end

    local directory_end = path:match("^.*()/")
    if directory_end and directory_end > 1 then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, row, 0, {
        end_col = directory_end - 1,
        hl_group = config.hl.directory_path or "Comment",
        priority = 150,
      })
    end

    if location_end <= #line_content then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, row, location_start, {
        end_col = location_end,
        hl_group = config.hl.grep_line_number or "LineNr",
        priority = 150,
      })
    end

    if separator_end <= #line_content then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, row, separator_start, {
        end_col = separator_end,
        hl_group = "Comment",
        priority = 150,
      })
    end

    if item._trimmed_content and item.name then
      ctx._ts_lang_cache = ctx._ts_lang_cache or {}

      local lang = ctx._ts_lang_cache[item.name]
      if lang == nil then
        lang = treesitter_highlight.lang_from_filename(item.name) or false
        ctx._ts_lang_cache[item.name] = lang
      end

      if lang then
        local highlights = treesitter_highlight.get_line_highlights(item._trimmed_content, lang)
        for _, hl in ipairs(highlights) do
          local hl_start = content_start + hl.col
          local hl_end = content_start + hl.end_col

          if hl_start < #line_content and hl_end <= #line_content then
            pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, row, hl_start, {
              end_col = hl_end,
              hl_group = hl.hl_group,
              priority = 120,
            })
          end
        end
      end
    end

    if item.match_ranges then
      for _, range in ipairs(item.match_ranges) do
        local raw_start = math.max(0, range[1] or 0)
        local raw_end = range[2] or 0

        if raw_end > 0 then
          local hl_start = content_start + raw_start
          local hl_end = content_start + raw_end

          if hl_start < #line_content and hl_end <= #line_content then
            pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, row, hl_start, {
              end_col = hl_end,
              hl_group = config.hl.grep_match or "IncSearch",
              priority = 200,
            })
          end
        end
      end
    end

    if ctx.selected_items then
      local key = string.format("%s:%d:%d", item.path, item.line_number or 0, item.col or 0)
      if ctx.selected_items[key] then
        vim.api.nvim_buf_set_extmark(buf, ns_id, row, 0, {
          sign_text = "▊",
          sign_hl_group = config.hl.selected or "FFFSelected",
          priority = 1001,
        })
      end
    end
  end

  grep_renderer._flat_layout_patched = true
  return grep_renderer
end

local set_fff_window_options = function(win)
  if not win or not vim.api.nvim_win_is_valid(win) then return end

  vim.api.nvim_set_option_value("scrolloff", 0, { win = win })
  vim.api.nvim_set_option_value("sidescrolloff", 0, { win = win })
end

local set_fff_window_border = function(win, border)
  if not win or not vim.api.nvim_win_is_valid(win) then return end

  local config = vim.api.nvim_win_get_config(win)
  config.border = border
  vim.api.nvim_win_set_config(win, config)
end

local apply_fff_window_tweaks = function(picker_ui)
  set_fff_window_options(picker_ui.state.list_win)
  set_fff_window_options(picker_ui.state.input_win)
  set_fff_window_options(picker_ui.state.preview_win)
  set_fff_window_options(picker_ui.state.file_info_win)

  if picker_ui.state.list_win and vim.api.nvim_win_is_valid(picker_ui.state.list_win) then
    vim.api.nvim_set_option_value("signcolumn", "no", { win = picker_ui.state.list_win })
  end

  set_fff_window_border(picker_ui.state.list_win, FFF_LIST_BORDER)
  set_fff_window_border(picker_ui.state.input_win, FFF_INPUT_BORDER)
  set_fff_window_border(picker_ui.state.preview_win, FFF_PREVIEW_BORDER)
end

local patch_fff_picker_ui = function()
  local picker_ui = require("fff.picker_ui")

  if not picker_ui._fzf_layout_patched then
    local original_calculate_layout_dimensions = picker_ui.calculate_layout_dimensions

    picker_ui.calculate_layout_dimensions = function(cfg)
      local layout = original_calculate_layout_dimensions(cfg)

      if
        cfg.prompt_position == "bottom"
        and layout.preview
        and (cfg.preview_position == "left" or cfg.preview_position == "right")
      then
        layout.preview.row = layout.list_row
        layout.preview.height = layout.list_height

        if cfg.preview_position == "right" then
          layout.preview.col = layout.preview.col - 1
        elseif cfg.preview_position == "left" then
          layout.preview.col = layout.preview.col + 1
        end
      end

      return layout
    end

    picker_ui._fzf_layout_patched = true
  end

  if not picker_ui._fzf_create_ui_wrapped then
    local original_create_ui = picker_ui.create_ui
    picker_ui.create_ui = function(...)
      local ok, result = pcall(original_create_ui, ...)

      if ok and result then apply_fff_window_tweaks(picker_ui) end
      if ok then return result end
      error(result)
    end

    picker_ui._fzf_create_ui_wrapped = true
  end

  if not picker_ui._fzf_relayout_wrapped then
    local original_relayout = picker_ui.relayout
    picker_ui.relayout = function(...)
      local ok, result = pcall(original_relayout, ...)

      if ok then
        if picker_ui.state.active then apply_fff_window_tweaks(picker_ui) end
        return result
      end

      error(result)
    end

    picker_ui._fzf_relayout_wrapped = true
  end

  if not picker_ui._fzf_update_results_sync_wrapped then
    local original_update_results_sync = picker_ui.update_results_sync
    picker_ui.update_results_sync = function(...)
      maybe_sync_fff_grep_mode(picker_ui)
      local result = original_update_results_sync(...)
      local state = picker_ui.state

      if state and state.suggestion_source then
        state.suggestion_items = nil
        state.suggestion_source = nil
        state.filtered_items = state.items or {}
        state.cursor = #state.filtered_items > 0 and 1 or 1

        if state.active then picker_ui.render_debounced() end
      end

      return result
    end

    picker_ui._fzf_update_results_sync_wrapped = true
  end

  if picker_ui._single_border_close_wrapped then return picker_ui end

  local original_close = picker_ui.close
  picker_ui.close = function(...)
    capture_fff_session(picker_ui)

    local previous_winborder = picker_ui._previous_winborder
    local ok, result = pcall(original_close, ...)

    if previous_winborder ~= nil then
      vim.o.winborder = previous_winborder
      picker_ui._previous_winborder = nil
    end

    if ok then return result end
    error(result)
  end

  picker_ui._single_border_close_wrapped = true
  return picker_ui
end

local wrap_fff_picker = function(open_picker)
  return function(...)
    local picker_ui = patch_fff_picker_ui()
    set_last_picker_backend("fff")

    if picker_ui._previous_winborder == nil then picker_ui._previous_winborder = vim.o.winborder end

    vim.o.winborder = FFF_BORDER_STYLE

    local ok, result = pcall(open_picker, ...)

    if ok then return result end

    if picker_ui._previous_winborder ~= nil then
      vim.o.winborder = picker_ui._previous_winborder
      picker_ui._previous_winborder = nil
    end

    error(result)
  end
end

local get_fff_context_cwd = function()
  if lib.buffer.current.get_filetype() ~= "NvimTree" then return nil end

  local ok, api = pcall(require, "nvim-tree.api")
  if not ok then return nil end

  local node = api.tree.get_node_under_cursor()
  if not node or not node.absolute_path or #node.absolute_path == 0 then return nil end

  if node.type == "directory" then return node.absolute_path end

  return vim.fn.fnamemodify(node.absolute_path, ":h")
end

local get_rooter = function()
  local ok, rooter = pcall(require, "modules/workflow/rooter")
  if not ok or not rooter or not rooter.exports then return nil end
  return rooter.exports
end

local get_fff_sticky_cwd = function()
  if FFF_STICKY_CWD then return FFF_STICKY_CWD end

  local rooter = get_rooter()
  if rooter and rooter.get_cwd then
    FFF_STICKY_CWD = rooter.get_cwd()
    if FFF_STICKY_CWD then return FFF_STICKY_CWD end
  end

  FFF_STICKY_CWD = vim.uv.cwd()
  return FFF_STICKY_CWD
end

local get_fff_find_files_opts = function()
  local cwd = get_fff_sticky_cwd()
  if not cwd then return {} end

  return { cwd = cwd }
end

local get_fff_live_grep_opts = function(opts)
  local grep_opts = vim.tbl_deep_extend("force", {
    grep = {
      auto_exact_on_uppercase = true,
      modes = { "fuzzy", "plain" },
    },
  }, opts or {})

  local cwd = get_fff_sticky_cwd()
  if cwd and grep_opts.cwd == nil then grep_opts.cwd = cwd end

  return grep_opts
end

local normalize_fff_query = function(text)
  if type(text) ~= "string" then return nil end

  local query = vim.trim(text:gsub("%s*\n%s*", " "))
  if query == "" then return nil end

  return query
end

fff_query_has_uppercase = function(query)
  return type(query) == "string" and query:find("%u") ~= nil
end

maybe_sync_fff_grep_mode = function(picker_ui)
  local state = picker_ui.state
  if not state or not state.active or state.mode ~= "grep" then return end

  local grep_config = state.grep_config or {}
  if not grep_config.auto_exact_on_uppercase then return end

  local modes = grep_config.modes or {}
  if not vim.tbl_contains(modes, "fuzzy") or not vim.tbl_contains(modes, "plain") then return end

  local target_mode = fff_query_has_uppercase(state.query) and "plain" or "fuzzy"
  if state.grep_mode == target_mode then return end

  state.grep_mode = target_mode
  state.grep_regex_fallback_error = nil
  state.last_status_info = nil
end

local setup_fff = function(_, opts)
  local sticky_cwd = get_fff_sticky_cwd()
  local fff = require("fff")
  fff.setup(vim.tbl_deep_extend("force", {
    base_path = sticky_cwd,
  }, opts or {}))

  patch_fff_picker_ui()
  patch_fff_grep_renderer()

  if fff._single_border_wrapped then return end

  -- fff reads vim.o.winborder when opening its floats.
  fff.find_files = wrap_fff_picker(fff.find_files)
  fff.find_files_in_dir = wrap_fff_picker(fff.find_files_in_dir)
  fff.live_grep = wrap_fff_picker(fff.live_grep)
  fff.open_file_under_cursor = wrap_fff_picker(fff.open_file_under_cursor)
  fff.resume_last = resume_fff_session
  if fff.resume == nil then fff.resume = resume_fff_session end
  fff._single_border_wrapped = true
end

local setup_fzf_lua = function()
  local fzf = require("fzf-lua")
  local fff = require("fff")

  local base_fd_command = "rg --files --hidden --glob '!.git' --glob '!*[-\\.]lock\\.*' --smart-case"

  local config = {
    -- defaults = {
    --   formatter = { "path.filename_first", 2 },
    -- },
    fzf_opts = {
      ["--layout"] = "default",
      ["--highlight-line"] = true,
      ["--prompt"] = SEARCH_PROMPT,
    },
    rg_opts = { ["--column"] = "" },
    winopts = {
      split = "botright new",
      fullscreen = true,
      preview = {
        default = "bat",
        delay = 15,
        layout = "horizontal",
        horizontal = "right:40%",
        wrap = false,
      },
      on_create = function()
        vim.api.nvim_buf_set_keymap(0, "t", "<C-j>", "<Down>", { silent = true })
        vim.api.nvim_buf_set_keymap(0, "t", "<C-k>", "<Up>", { silent = true })
      end,
      backdrop = 100,
    },
    previewers = {
      bat = {
        cmd = "bat",
        args = "--color always --style=numbers,changes --wrap=auto",
        theme = "OneHalfDark",
        config = nil,
      },
    },
    files = {
      cmd = base_fd_command,
      -- path_shorten = 4,
      git_icons = false,
      fzf_opts = {
        ["--tiebreak"] = "index",
      },
    },
    buffers = {
      -- path_shorten = 4,
    },
    grep = {
      rg_opts = "--hidden --glob '!.git' --glob '!*[-\\.]lock\\.*' --glob '!LICENSE' --column --line-number --no-heading --color=always --smart-case --max-columns=4096 -e",
      -- path_shorten = 4,
      git_icons = false,
      fzf_opts = { ["--layout"] = "default", ["--no-hscroll"] = "" },
      -- rg_opts = "--hidden",
    },
    tags = { git_icons = false },
    btags = { git_icons = false },
    keymap = { builtin = {} },
  }
  fzf.setup(config)

  -- lib.map.map("n", "<c-p>", function()
  --   set_last_picker_backend("fzf_lua")
  --   local fd_command = base_fd_command
  --   if vim.fn.expand("%:p:h") ~= vim.uv.cwd() then
  --     local prox = vim.fn.exepath("proximity-sort")
  --     if prox ~= nil and #prox > 0 then
  --       local libuv = require("fzf-lua.libuv")
  --       fd_command = base_fd_command
  --         .. " | "
  --         .. libuv.shellescape(prox)
  --         .. " "
  --         .. libuv.shellescape(vim.fn.expand("%:."))
  --     end
  --   end
  --   fzf.files({ cmd = fd_command })
  -- end, "Find file in project")
  lib.map.map("n", "<c-p>", function()
    find_files()
  end, "Find file in project")

  lib.map.map("n", ";", function()
    buffers()
  end, "Find buffer")

  -- lib.map.map("n", "<c-f>", function()
  --   set_last_picker_backend("fzf_lua")
  --   local opts = {}
  --   -- nvim-tree
  --   if vim.bo.filetype == "NvimTree" then
  --     local ok, api = pcall(require, "nvim-tree.api")
  --     if ok then
  --       local node = api.tree.get_node_under_cursor()
  --       if node and node.absolute_path and #node.absolute_path > 0 then
  --         if node.type == "directory" then
  --           opts.search_paths = { node.absolute_path }
  --         else
  --           opts.filename = node.absolute_path
  --         end
  --       end
  --     end
  --   end
  --   fzf.grep_project(opts)
  -- end, "Find text in project")
  lib.map.map("n", "<c-f>", function()
    live_grep()
  end, "Find text in project")

  lib.map.map("n", "<leader>l", function()
    buffer_lines()
  end, "Find line in buffer")
  lib.map.map("n", "<leader>L", function()
    lines()
  end, "Find line in open buffers")
  lib.map.map("n", "<leader>;", resume_last_picker, "Resume last picker")

  -- visual
  -- lib.map.map("v", "<c-f>", function()
  --   set_last_picker_backend("fzf_lua")
  --   local opts = {}
  --   if type(config) == "table" and type(config.grep) == "table" and type(config.grep.rg_opts) == "string" then
  --     opts.rg_opts = (config.grep.rg_opts:gsub("%-%-color=always", "--color=never"))
  --   end
  --   local prox = vim.fn.exepath("proximity-sort")
  --   if prox and #prox > 0 then
  --     local ctx = vim.fn.expand("%:.")
  --     if ctx and #ctx > 0 then
  --       local libuv = require("fzf-lua.libuv")
  --       opts.filter = string.format("%s %s", libuv.shellescape(prox), libuv.shellescape(ctx))
  --     end
  --   end
  --   require("fzf-lua").grep_visual(opts)
  -- end, "Find selected text in project")
  lib.map.map("v", "<c-f>", function()
    live_grep_selection()
  end, "Find selected text in project")
end

find_files = function(opts)
  local fff = require("fff")
  set_last_picker_backend("fff")
  fff.find_files(vim.tbl_deep_extend("force", get_fff_find_files_opts(), opts or {}))
end

live_grep = function(opts)
  local fff = require("fff")
  set_last_picker_backend("fff")
  fff.live_grep(get_fff_live_grep_opts(opts))
end

live_grep_selection = function()
  local query = normalize_fff_query(lib.buffer.current.get_selected_text())
  if not query then return end
  live_grep({ query = query })
end

buffers = function(opts)
  local fzf = require("fzf-lua")
  set_last_picker_backend("fzf_lua")
  fzf.buffers(opts or {})
end

buffer_lines = function(opts)
  local fzf = require("fzf-lua")
  set_last_picker_backend("fzf_lua")
  fzf.blines(opts or {})
end

lines = function(opts)
  local fzf = require("fzf-lua")
  set_last_picker_backend("fzf_lua")
  fzf.lines(opts or {})
end

lsp_references = function(opts)
  local fzf = require("fzf-lua")
  set_last_picker_backend("fzf_lua")
  fzf.lsp_references(opts or {})
end

lsp_workspace_symbols = function(opts)
  local fzf = require("fzf-lua")
  set_last_picker_backend("fzf_lua")
  fzf.lsp_workspace_symbols(vim.tbl_deep_extend("force", {
    file_ignore_patterns = { "node_modules" },
    no_header_i = true,
    previewer = "builtin",
  }, opts or {}))
end

return lib.module.create({
  name = "workflow/fzf",
  hosts = "*",
  plugins = {
    {
      "ibhagwan/fzf-lua",
      -- commit = "a1a2d0f42eaec400cc6918a8e898fc1f9c4dbc5f", -- issues introduced by https://github.com/ibhagwan/fzf-lua/commit/b3b05f9d438736bb1f88aa373476753ddf83f481
      -- commit = "60428a8dc931639ee5e88756b2d7bc896cdc20c7",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "fzf"),
      event = "VeryLazy",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = setup_fzf_lua,
    },
    { "vijaymarupudi/nvim-fzf", event = "VeryLazy" },
    {
      "dmtrKovalenko/fff.nvim",
      commit = "bb6f32a2ada380711f08bb11ba49e6fab23f191b",
      build = get_fff_build(),
      config = setup_fff,
      opts = {
        debug = {
          enabled = false,
          show_scores = false,
        },
        prompt = SEARCH_PROMPT,
        title = "Files",
        layout = FFF_LAYOUT,
        keymaps = {
          move_up = { "<Up>", "<C-p>", "<C-k>" },
          move_down = { "<Down>", "<C-n>", "<C-j>" },
        },
      },
      lazy = false,
    },
  },
  exports = {
    find_files = find_files,
    live_grep = live_grep,
    live_grep_selection = live_grep_selection,
    buffers = buffers,
    buffer_lines = buffer_lines,
    lines = lines,
    resume = resume_last_picker,
    lsp_references = lsp_references,
    lsp_workspace_symbols = lsp_workspace_symbols,
  },
})

local setup_auto_session = function()
  require("auto-session").setup({
    log_level = "error",
    auto_session_enabled = true,
    auto_save_enabled = true,
    auto_restore_enabled = true,
    auto_session_create_enabled = false,
    auto_session_enable_last_session = false,
    auto_session_root_dir = lib.env.dirs.vim.sessions .. "/",
    auto_session_suppress_dirs = { "~/", "~/Downloads", "~/Desktop" },
    cwd_change_handling = {
      restore_upcoming_session = false,
    },
    pre_save_cmds = {
      -- close floating windows
      function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local config = vim.api.nvim_win_get_config(win)
          if config.relative ~= "" then vim.api.nvim_win_close(win, false) end
        end
      end,
      -- close no-name buffers
      function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_get_name(buf) == "" then vim.api.nvim_buf_delete(buf, {}) end
        end
      end,
      -- close nvim-tree
      function()
        local ok, api = pcall(require, "nvim-tree.api")
        if ok then api.tree.close_in_all_tabs() end
      end,
    },
  })

  vim.o.sessionoptions = "buffers,tabpages,winsize,winpos,terminal"
end

-- local toggle_session = function()
--   local autosession = require("auto-session")
--   local autosession_lib = require("auto-session/lib")
--   local session_file = ("%s/%s.vim"):format(lib.env.dirs.vim.sessions, autosession_lib.escaped_session_name_from_cwd())
--   local has_session = lib.fs.file.is_readable(session_file)
--   if has_session then
--     autosession.DeleteSession()
--     log("Deleted session")
--   else
--     ---@diagnostic disable-next-line: missing-parameter
--     autosession.SaveSession()
--     log("Created session")
--   end
-- end

local toggle_session = function()
  local Path = require("plenary.path")
  local session_manager = require("session_manager")
  -- local config = require("session_manager.config")
  local utils = require("session_manager.utils")
  local last_session = utils.get_last_session_filename()

  if last_session then
    utils.is_session = false
    -- config.autosave_last_session = false -- when autosave_only_in_session == false
    Path:new(last_session):rm()
    log("Deleted session")
  else
    ---@diagnostic disable-next-line: missing-parameter
    session_manager.save_current_session()
    log("Created session")
  end
end

return lib.module.create({
  -- enabled = false,
  name = "workflow/sessions",
  plugins = {
    -- {
    --   "rmagatti/auto-session",
    --   event = "VimEnter",
    --   config = setup_auto_session,
    -- },
    -- { "olimorris/persisted.nvim" },
    {
      "Shatur/neovim-session-manager",
      event = "VeryLazy",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        local Path = require("plenary.path")
        local config = require("session_manager.config")
        require("session_manager").setup({
          sessions_dir = Path:new(lib.env.dirs.vim.sessions),
          -- session_filename_to_dir = session_filename_to_dir,
          -- dir_to_session_filename = dir_to_session_filename,
          autoload_mode = config.AutoloadMode.Disabled,
          autosave_last_session = true,
          autosave_ignore_not_normal = true,
          autosave_ignore_dirs = {},
          autosave_ignore_filetypes = {
            "gitcommit",
            "gitrebase",
          },
          autosave_ignore_buftypes = {},
          autosave_only_in_session = true,
          max_path_length = 80,
        })
        if vim.fn.argc() == 0 and not vim.g.started_with_stdin then
          require("session_manager").load_current_dir_session()
        end
      end,
    },
  },
  mappings = {
    { "n", "<leader>s", toggle_session, "Toggle session" },
  },
})

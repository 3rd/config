local setup_auto_session = function()
  require("auto-session").setup({
    log_level = "error",
    auto_session_enabled = true,
    auto_session_enable_last_session = false,
    auto_session_root_dir = lib.env.dirs.vim.sessions .. "/",
    auto_session_suppress_dirs = { "~/", "~/Downloads", "~/Desktop" },
    auto_save_enabled = true,
    auto_restore_enabled = true,
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

  vim.o.sessionoptions = "buffers,folds,tabpages,winsize,winpos,terminal,localoptions"
end

local has_session = true
local toggle_session = function()
  local autosession = require("auto-session")
  local autosession_lib = require("auto-session/lib")
  local does_actually_have_session = pcall(autosession_lib.current_session_name)
  if not does_actually_have_session then has_session = false end
  if has_session then
    autosession.DeleteSession()
    has_session = false
    log("Deleted session")
  else
    autosession.SaveSession(lib.env.dirs.vim.sessions .. "/", false)
    has_session = true
    log("Created session")
  end
end

return lib.module.create({
  name = "workflow/sessions",
  plugins = {
    {
      "rmagatti/auto-session",
      -- commit = "63984ed9c0fb7eae61eb1c2982bc1147e202d23e",
      -- branch = "fix-telescope-dependency",
      event = "VimEnter",
      config = setup_auto_session,
    },
    -- { "olimorris/persisted.nvim" } -- alternative
  },
  mappings = {
    { "n", "<leader>s", toggle_session, "Toggle session" },
  },
})

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
    silent_restore = true,
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

  vim.o.sessionoptions = "buffers,tabpages,winsize,winpos,terminal,localoptions"
end

local toggle_session = function()
  local autosession = require("auto-session")
  local autosession_lib = require("auto-session/lib")
  local session_file = ("%s/%s.vim"):format(
    lib.env.dirs.vim.sessions,
    -- https://github.com/rmagatti/auto-session/blob/00334ee24b9a05001ad50221c8daffbeedaa0842/lua/auto-session/lib.lua#L32
    vim.fn.fnamemodify(vim.v.this_session, ":t:r")
    -- autosession_lib.get_session_display_name(vim.fn.getcwd())
  )
  log(session_file)
  local has_session = lib.fs.file.is_readable(session_file)
  if has_session then
    autosession.DeleteSession()
    log("Deleted session")
  else
    ---@diagnostic disable-next-line: missing-parameter
    autosession.SaveSession()
    log("Created session")
  end
end

return lib.module.create({
  name = "workflow/sessions",
  -- enabled = false,
  hosts = "*",
  plugins = {
    {
      "rmagatti/auto-session",
      -- commit = "2102c228854a2d74fbf35374aa86feac3f538da1",
      lazy = false,
      config = setup_auto_session,
    },
  },
  mappings = {
    { "n", "<leader>s", toggle_session, "Toggle session" },
  },
})

local setup_vim_workspace = function()
  vim.g.workspace_autosave = 0
  vim.g.workspace_create_new_tabs = 0
  vim.g.workspace_persist_undo_history = 0
  vim.g.workspace_session_directory = vim.fn.stdpath("config") .. "/.sessions/"
  vim.g.workspace_session_disable_on_args = 0
  vim.g.workspace_session_name = "session.vim"
  vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal"
end

local setup_lastplace = function()
  local lastplace = require("nvim-lastplace")
  lastplace.setup({
    lastplace_ignore_buftype = { "quickfix", "nofile", "help" },
    lastplace_ignore_filetype = { "gitcommit", "gitrebase" },
    lastplace_open_folds = false,
  })
end

return require("lib").module.create({
  name = "workflow/session-management",
  plugins = {
    { "thaerkh/vim-workspace", config = setup_vim_workspace },
    { "ethanholz/nvim-lastplace", config = setup_lastplace },
  },
  mappings = {
    { "n", "<leader>s", ":ToggleWorkspace<cr>" },
  },
})

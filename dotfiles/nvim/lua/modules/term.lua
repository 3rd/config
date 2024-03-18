return lib.module.create({
  name = "term",
  setup = function()
    -- options
    vim.g.terminal_scrollback_buffer_size = 100000

    -- auto-commands
    vim.api.nvim_command("autocmd TermOpen * startinsert")
    vim.api.nvim_command("autocmd TermOpen * setlocal nonumber")
    vim.api.nvim_command("autocmd TermEnter * setlocal signcolumn=no")

    -- binds
    vim.keymap.set("t", "<c-s-c>", "<C-\\><C-n>")
  end,
})

return lib.module.create({
  name = "term",
  setup = function()
    vim.api.nvim_command("autocmd TermOpen * startinsert") -- starts in insert mode
    vim.api.nvim_command("autocmd TermOpen * setlocal nonumber") -- no numbers
    vim.api.nvim_command("autocmd TermEnter * setlocal signcolumn=no") -- no sign column
  end,
})

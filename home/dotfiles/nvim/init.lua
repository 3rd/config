vim.loader.enable()
require("config")

-- crazy resize/cmdheight bug
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "WinScrolled" }, {
  callback = function()
    vim.opt.cmdheight = 1
  end,
})


vim.loader.enable()
require("config")

-- https://github.com/neovim/neovim/issues/21856
vim.api.nvim_create_autocmd({ "VimLeave" }, {
  callback = function()
    vim.cmd("sleep 10m")
  end,
})

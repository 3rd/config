local setup = function()
  require("focus").setup({
    enable = true,
    signcolumn = false,
  })
  vim.cmd("FocusDisable")
end

return require("lib").module.create({
  name = "ui/focus",
  plugins = {
    { "beauwilliams/focus.nvim", config = setup },
  },
  mappings = {
    { "n", "<c-left>", ":FocusSplitLeft<CR>", { silent = true } },
    { "n", "<c-down>", ":FocusSplitDown<CR>", { silent = true } },
    { "n", "<c-up>", ":FocusSplitUp<CR>", { silent = true } },
    { "n", "<c-right>", ":FocusSplitRight<CR>", { silent = true } },
  },
})

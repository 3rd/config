local setup_live_command = function()
  require("live-command").setup({
    commands = {
      Norm = { cmd = "norm" },
    },
  })
end

local setup_text_case = function()
  require("textcase").setup({})
end

return require("lib").module.create({
  name = "workflow/text-editing",
  plugins = {
    { "christoomey/vim-sort-motion" },
    { "tpope/vim-surround" },
    { "tommcdo/vim-lion" },
    { "smjonas/live-command.nvim", config = setup_live_command },
    { "johmsalas/text-case.nvim", config = setup_text_case },
  },
})

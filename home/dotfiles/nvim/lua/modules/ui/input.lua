local setup = {
  dressing = function()
    require("dressing").setup({
      input = {
        winblend = 0,
        winhighlight = "NormalFloat:Normal",
        override = function(conf)
          conf.col = -1
          conf.row = 0
          return conf
        end,
      },
      select = {
        enabled = false,
        backend = { "fzf_lua", "fzf", "builtin" },
      },
    })
  end,
}

return require("lib").module.create({
  name = "ui/input",
  plugins = {
    { "stevearc/dressing.nvim", config = setup.dressing },
    { "MunifTanjim/nui.nvim" },
  },
})

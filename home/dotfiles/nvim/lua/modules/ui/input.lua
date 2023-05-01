local setup_dressing = function()
  require("dressing").setup({
    input = {
      win_options = {
        winblend = 0,
        winhighlight = "NormalFloat:Normal",
      },
      override = function(conf)
        conf.col = -1
        conf.row = 0
        return conf
      end,
    },
    select = {
      enabled = true,
      backend = { "fzf_lua", "fzf", "builtin" },
    },
  })
end

return lib.module.create({
  name = "ui/input",
  plugins = {
    {
      "stevearc/dressing.nvim",
      event = "VeryLazy",
      config = setup_dressing,
    },
    { "MunifTanjim/nui.nvim" },
  },
})

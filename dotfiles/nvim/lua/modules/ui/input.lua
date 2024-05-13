return lib.module.create({
  name = "ui/input",
  hosts = "*",
  plugins = {
    {
      "stevearc/dressing.nvim",
      event = "VeryLazy",
      opts = {
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
      },
    },
    { "MunifTanjim/nui.nvim" },
  },
})

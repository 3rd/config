return lib.module.create({
  name = "misc/which-key-map",
  plugins = {
    {
      "folke/which-key.nvim",
      event = "VeryLazy",
      config = function()
        local wk = require("which-key")

        wk.setup({
          plugins = {
            marks = false,
            registers = false,
            spelling = { enabled = false },
            presets = {
              operators = false,
              motions = false,
              text_objects = false,
              windows = false,
              nav = false,
              z = false,
              g = true,
            },
          },
          window = {
            border = "single",
            position = "bottom",
            margin = { 1, 0, 1, 0 },
            padding = { 1, 1, 1, 1 },
            winblend = 0,
          },
          disable = {
            buftypes = {},
            filetypes = {},
          },
        })

        wk.register({
          ["<leader>a"] = { name = "+actions" },
          ["<leader>e"] = { name = "+edit" },
          ["<leader>d"] = { name = "+debugger" },
        })
      end,
    },
  },
})

return lib.module.create({
  name = "misc/which-key-map",
  hosts = "*",
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
          ["<leader>"] = {
            a = { name = "+actions" },
            b = { name = "+edit" },
            c = { name = "+debugger" },
            ["1"] = "which_key_ignore",
            ["2"] = "which_key_ignore",
            ["3"] = "which_key_ignore",
            ["4"] = "which_key_ignore",
            ["5"] = "which_key_ignore",
            ["6"] = "which_key_ignore",
            ["7"] = "which_key_ignore",
            ["8"] = "which_key_ignore",
            ["9"] = "which_key_ignore",
            ["0"] = "which_key_ignore",
          },
        })

        -- workaround, which-key breaks number mappings
        require("modules/workflow/javelin").setup()
      end,
    },
  },
})

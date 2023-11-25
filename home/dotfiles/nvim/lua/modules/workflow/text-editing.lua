return lib.module.create({
  name = "workflow/text-editing",
  plugins = {
    {
      "christoomey/vim-sort-motion", -- gs
      event = "VeryLazy",
    },
    {
      "tommcdo/vim-lion", -- gl
      event = "VeryLazy",
    },
    {
      "kylechui/nvim-surround",
      event = "VeryLazy",
      opts = {
        keymaps = {
          insert = "<C-g>s",
          insert_line = "<C-g>S",
          normal = "ys",
          normal_cur = "yss",
          normal_line = "yS",
          normal_cur_line = "ySS",
          visual = "S",
          visual_line = "gS",
          delete = "ds",
          change = "cs",
        },
      },
    },
    {
      "Wansmer/sibling-swap.nvim",
      dependencies = { "nvim-treesitter" },
      lazy = false,
      config = function()
        require("sibling-swap").setup({
          allowed_separators = {
            ",",
            ";",
            "and",
            "or",
            "&&",
            "&",
            "||",
            "|",
            "==",
            "===",
            "!=",
            "!==",
            "-",
            "+",
            ["<"] = ">",
            ["<="] = ">=",
            [">"] = "<",
            [">="] = "<=",
          },
          keymaps = {
            ["<a-l>"] = "swap_with_right",
            ["<a-h>"] = "swap_with_left",
          },
          use_default_keymaps = true,
          highlight_node_at_cursor = false,
          ignore_injected_langs = false,
          allow_interline_swaps = true,
          interline_swaps_without_separator = false,
        })
      end,
    },
  },
})

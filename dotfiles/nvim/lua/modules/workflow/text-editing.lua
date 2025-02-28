return lib.module.create({
  name = "workflow/text-editing",
  hosts = "*",
  plugins = {
    {
      "christoomey/vim-sort-motion", -- gs
      keys = { "gs" },
    },
    {
      "tommcdo/vim-lion", -- gl
      keys = { "gl" },
    },
    {
      "kylechui/nvim-surround",
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
      keys = {
        "<C-g>s",
        "<C-g>S",
        "ys",
        "yss",
        "yS",
        "ySS",
        "S",
        "gS",
        "ds",
        "cs",
      },
    },
    {
      "Wansmer/sibling-swap.nvim",
      -- enabled = false,
      dependencies = { "nvim-treesitter" },
      config = function()
        require("sibling-swap").setup({
          keymaps = {
            ["<a-l>"] = "swap_with_right",
            ["<a-h>"] = "swap_with_left",
          },
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
          use_default_keymaps = false,
          highlight_node_at_cursor = false,
          ignore_injected_langs = false,
          allow_interline_swaps = true,
          interline_swaps_without_separator = false,
        })
      end,
      keys = {
        {
          "<a-l>",
          function()
            require("sibling-swap").swap_with_right()
          end,
          { desc = "Swap with right" },
        },
        {
          "<a-h>",
          function()
            require("sibling-swap").swap_with_left()
          end,
          { desc = "Swap with left" },
        },
      },
    },
  },
})

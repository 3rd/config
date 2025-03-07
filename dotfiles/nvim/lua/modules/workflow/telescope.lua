return lib.module.create({
  name = "language-support/call-sites",
  hosts = "*",
  plugins = {
    {
      "nvim-telescope/telescope.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
      event = "VeryLazy",
      config = function()
        local actions = require("telescope.actions")

        local layout_strategies = require("telescope.pickers.layout_strategies")
        layout_strategies.custom = function(picker, max_columns, max_lines, layout_config)
          local layout = layout_strategies.horizontal(picker, max_columns, max_lines, layout_config)
          layout.prompt.title = ""
          layout.results.title = ""
          layout.results.height = layout.results.height + 1
          layout.results.borderchars = { "─", "│", "─", "│", "╭", "┬", "┤", "├" }
          layout.prompt.borderchars = { "─", "│", "─", "│", "╭", "╮", "┴", "╰" }
          if layout.preview then
            layout.preview.title = ""
            layout.preview.borderchars = { "─", "│", "─", " ", "─", "╮", "╯", "─" }
          end
          return layout
        end

        require("telescope").setup({
          defaults = {
            default_mode = "insert",
            layout_strategy = "bottom_pane",
            layout_config = {
              prompt_position = "bottom",
            },
            mappings = {
              i = {
                ["<esc>"] = actions.close,
                ["<C-j>"] = actions.move_selection_next,
                ["<C-k>"] = actions.move_selection_previous,
                ["<cr>"] = actions.select_default + actions.center,
                ["<c-d>"] = actions.preview_scrolling_down,
                ["<c-u>"] = actions.preview_scrolling_up,
              },
              n = {
                -- ["<c-t>"] = require("trouble.sources.telescope").open,
              },
            },
          },
        })
      end,
      keys = {
        { "n", "gr", "<cmd>Telescope lsp_references<cr>", desc = "LSP: Go to references" },
      },
    },
    {
      "jmacadie/telescope-hierarchy.nvim",
      dependencies = {
        {
          "nvim-telescope/telescope.nvim",
          dependencies = { "nvim-lua/plenary.nvim" },
        },
      },
      keys = {
        {
          "<leader>gi",
          "<cmd>Telescope hierarchy incoming_calls<cr>",
          desc = "LSP: [S]earch [I]ncoming Calls",
        },
        {
          "<leader>go",
          "<cmd>Telescope hierarchy outgoing_calls<cr>",
          desc = "LSP: [S]earch [O]utgoing Calls",
        },
      },
      opts = {
        extensions = {
          hierarchy = {
            initial_multi_expand = false,
            multi_depth = 5,
            theme = "ivy",
            layout_strategy = "bottom_pane",
            layout_config = { height = 0.5 },
          },
        },
      },
      config = function(_, opts)
        -- Calling telescope's setup from multiple specs does not hurt, it will happily merge the
        -- configs for us. We won't use data, as everything is in it's own namespace (telescope
        -- defaults, as well as each extension).
        require("telescope").setup(opts)
        require("telescope").load_extension("hierarchy")
      end,
    },
  },
})

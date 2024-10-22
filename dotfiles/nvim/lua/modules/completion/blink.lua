return lib.module.create({
  name = "completion/blink",
  hosts = "*",
  -- enabled = false,
  plugins = {
    {
      "Saghen/blink.cmp",
      -- "3rd/blink.cmp",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "blink.cmp"),
      lazy = false, -- lazy loading handled internally
      -- optional: provides snippets for the snippet source
      dependencies = "rafamadriz/friendly-snippets",

      -- use a release tag to download pre-built binaries
      -- version = "nightly",
      -- version = "v0.*",
      build = "cargo build --release",
      -- OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
      -- build = 'cargo build --release',
      -- On musl libc based systems you need to add this flag
      -- build = 'RUSTFLAGS="-C target-feature=-crt-static" cargo build --release',

      opts = {
        accept = {
          create_undo_point = true,
          auto_brackets = {
            enabled = false,
            default_brackets = { "(", ")" },
            override_brackets_for_filetypes = {},
            force_allow_filetypes = {},
            blocked_filetypes = {},
            kind_resolution = {
              enabled = true,
              blocked_filetypes = { "typescriptreact", "javascriptreact", "vue" },
            },
            semantic_token_resolution = {
              enabled = true,
              blocked_filetypes = {},
              timeout_ms = 400,
            },
          },
        },

        trigger = {
          completion = {
            keyword_regex = "[%w_\\-]",
            blocked_trigger_characters = { " ", "\n", "\t" },
            show_on_insert_on_trigger_character = true,
            show_on_insert_blocked_trigger_characters = { "'", '"' },
            show_in_snippet = false,
          },
          signature_help = {
            enabled = false,
            blocked_trigger_characters = {},
            blocked_retrigger_characters = {},
            show_on_insert_on_trigger_character = true,
          },
        },

        highlight = {
          use_nvim_cmp_as_default = true,
          accept = { auto_brackets = { enabled = true } },
          trigger = { signature_help = { enabled = true } },
        },
        nerd_font_variant = "normal", -- mono|normal

        sources = {
          providers = {
            -- all of these properties work on every source
            {
              "blink.cmp.sources.lsp",
              name = "LSP",
              keyword_length = 0,
              score_offset = 0,
              trigger_characters = { "f", "o", "o" },
            },
            -- the following two sources have additional options
            {
              "blink.cmp.sources.path",
              name = "Path",
              score_offset = 3,
              opts = {
                trailing_slash = false,
                label_trailing_slash = true,
                get_cwd = function(context)
                  return vim.fn.expand(("#%d:p:h"):format(context.bufnr))
                end,
                show_hidden_files_by_default = true,
              },
            },
            {
              "blink.cmp.sources.snippets",
              name = "Snippets",
              score_offset = -3,
              -- similar to https://github.com/garymjr/nvim-snippets
              opts = {
                friendly_snippets = false,
                search_paths = { vim.fn.stdpath("config") .. "/snippets_vscode" },
                global_snippets = { "all" },
                extended_filetypes = {},
                ignored_filetypes = {},
              },
            },
            {
              "blink.cmp.sources.buffer",
              name = "Buffer",
              fallback_for = { "LSP" },
            },
          },
        },

        fuzzy = {
          keyword_range = "prefix",
          use_proximity = true,
          use_frecency = true,
          use_typo_resistance = true,
          max_items = 200,
          sorts = { "label", "kind", "score" },
          prebuiltBinaries = {
            download = false,
            forceVersion = nil,
          },
        },

        keymap = {
          show = "<C-space>",
          hide = "<C-e>",
          accept = "<CR>",
          select_next = { "<Down>", "<C-n>", "<Tab>" },
          select_prev = { "<Up>", "<C-p>", "<S-Tab>" },
          -- show_documentation = "",
          -- hide_documentation = "",
          scroll_documentation_up = "<C-d>",
          scroll_documentation_down = "<C-u>",
          snippet_forward = "<Tab>",
          snippet_backward = "<S-Tab>",
        },
        windows = {
          autocomplete = {
            min_width = 15,
            max_height = 10,
            border = "",
            scrolloff = 0,
            direction_priority = { "s", "n" },
            selection = "auto_insert",
            -- selection = "preselect",
            -- selection = "manual",
            -- 'function(blink.cmp.CompletionRenderContext): blink.cmp.Component[]' for custom rendering
            draw = "simple", -- simple | reversed | minimal | function
            cycle = {
              from_bottom = true,
              from_top = true,
            },
          },
          documentation = {
            min_width = 15,
            max_width = 60,
            max_height = 20,
            border = "rounded",
            direction_priority = {
              autocomplete_north = { "e", "w", "n", "s" },
              autocomplete_south = { "e", "w", "s", "n" },
            },
            auto_show = true,
            auto_show_delay_ms = 500,
            update_delay_ms = 50,
          },
          signature_help = {
            min_width = 1,
            max_width = 100,
            max_height = 10,
            border = "rounded",
            -- winhighlight = "Normal:BlinkCmpSignatureHelp,FloatBorder:BlinkCmpSignatureHelpBorder",
          },
        },

        kind_icons = {
          -- base
          Class = "󰠱",
          Color = "󰏘",
          Constant = "",
          Constructor = "",
          Enum = "",
          EnumMember = "",
          Event = "",
          Field = "󰅩",
          File = "󰈙",
          Folder = "󰉋",
          Function = "󰊕",
          Interface = "",
          Keyword = "󰌋",
          Method = "󰆧",
          Module = "",
          Operator = "󰆕",
          Property = "󰜢",
          Reference = "󰈇",
          Snippet = "",
          Struct = "󰙅",
          Text = "󰉿",
          TypeParameter = "󰊄",
          Unit = "",
          Value = "󰎠",
          Variable = "󰆧",
          -- tree-sitter
          String = "󰉿",
        },
      },
    },
    -- TODO: nvim-scissors
    {
      "smjonas/snippet-converter.nvim",
      enabled = false,
      config = function()
        local template = {
          sources = {
            snipmate = { vim.fn.stdpath("config") .. "/snippets_in" },
          },
          output = {
            vscode = { vim.fn.stdpath("config") .. "/snippets_out" },
          },
        }
        require("snippet_converter").setup({ templates = { template } })
      end,
    },
  },

  hooks = {
    lsp = {
      -- https://github.com/Saghen/blink.cmp/issues/21
      capabilities = function(capabilities)
        capabilities.textDocument.completion.completionItem.insertReplaceSupport = false
        return capabilities
      end,
    },
  },
  mappings = {
    {
      "i",
      "<Tab>",
      function()
        if vim.snippet.active({ direction = 1 }) then
          vim.schedule(function()
            vim.snippet.jump(1)
          end)
          return
        end
        return "<Tab>"
      end,
      { expr = true, silent = true },
    },
    {
      "s",
      "<Tab>",
      function()
        vim.schedule(function()
          vim.snippet.jump(1)
        end)
      end,
      { expr = true, silent = true },
    },
    {
      "i",
      "<S-Tab>",
      function()
        if vim.snippet.active({ direction = -1 }) then
          vim.schedule(function()
            vim.snippet.jump(-1)
          end)
          return
        end
        return "<S-Tab>"
      end,
      { expr = true, silent = true },
    },
  },
})

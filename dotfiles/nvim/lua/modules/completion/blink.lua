return lib.module.create({
  name = "completion/blink",
  hosts = "*",
  -- enabled = false,
  plugins = {
    {
      "Saghen/blink.cmp",
      -- commit = "c218fafbf275725532f3cf2eaebdf863b958d48e",
      -- commit = "88f1c203465fa3d883f2309bc22412c90a9f6a08",
      -- "3rd/blink.cmp",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "blink.cmp"),
      lazy = false, -- lazy loading handled internally
      -- optional: provides snippets for the snippet source
      -- dependencies = "rafamadriz/friendly-snippets",

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

        fuzzy = {
          use_typo_resistance = true,
          prebuiltBinaries = {
            download = false,
            forceVersion = nil,
          },
        },

        keymap = {
          ["<C-space>"] = { "show" },
          ["<C-e>"] = { "hide" },
          ["<CR>"] = { "accept", "fallback" },
          ["<Tab>"] = { "snippet_forward", "select_next", "fallback" },
          ["<S-Tab>"] = { "snippet_backward", "select_prev", "fallback" },
          ["<C-u>"] = { "scroll_documentation_up", "fallback" },
          ["<C-d>"] = { "scroll_documentation_down", "fallback" },
        },
        windows = {
          autocomplete = {
            selection = "auto_insert",
            -- selection = "preselect",
            -- selection = "manual",
            -- 'function(blink.cmp.CompletionRenderContext): blink.cmp.Component[]' for custom rendering
            draw = "simple", -- simple | reversed | minimal | function
            direction_priority = { "s", "n" },
            scrolloff = 2,
          },
          documentation = {
            min_width = 15,
            max_width = 60,
            max_height = 20,
            auto_show = true,
            auto_show_delay_ms = 500,
            update_delay_ms = 50,
            winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,CursorLine:BlinkCmpDocCursorLine,Search:None",
          },
          signature_help = {
            min_width = 1,
            max_width = 100,
            max_height = 10,
            border = "rounded",
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

        sources = {
          completion = {
            enabled_providers = { "lsp", "path", "snippets", "buffer", "lazydev" },
          },
          providers = {
            lsp = { fallback_for = { "lazydev" } },
            lazydev = { name = "LazyDev", module = "lazydev.integrations.blink" },
            snippets = {
              name = "Snippets",
              module = "blink.cmp.sources.snippets",
              score_offset = -3,
              opts = {
                friendly_snippets = false,
                search_paths = { vim.fn.stdpath("config") .. "/snippets_vscode" },
                global_snippets = { "all" },
                extended_filetypes = {},
                ignored_filetypes = {},
              },
            },
          },
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

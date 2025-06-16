local filter_kinds = { ["1"] = true }

return lib.module.create({
  name = "completion/blink",
  hosts = "*",
  -- enabled = false,
  plugins = {
    {
      "Saghen/blink.cmp",
      -- commit = "c218fafbf275725532f3cf2eaebdf863b958d48e",
      -- commit = "88f1c203465fa3d883f2309bc22412c90a9f6a08",
      -- commit = "77f037cae07358368f3b7548ba39cffceb49349e",
      -- commit = "7ceff61595aae682b421a68e208719b1523c7b44", -- new config
      -- commit = "e3b7cb4a1094377c3093a021300de123d9fc60d3",
      -- "3rd/blink.cmp",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "blink.cmp"),
      lazy = false,
      -- version = "nightly",
      -- version = "v0.*",
      build = "cargo build --release",
      dependencies = {
        { "xzbdmw/colorful-menu.nvim", opts = {} },
      },
      opts = {
        keymap = {
          ["<C-space>"] = { "show" },
          ["<C-e>"] = { "hide" },
          ["<CR>"] = { "accept", "fallback" },
          ["<Tab>"] = { "snippet_forward", "select_next", "fallback" },
          ["<S-Tab>"] = { "snippet_backward", "select_prev", "fallback" },
          ["<C-u>"] = { "scroll_documentation_up", "fallback" },
          ["<C-d>"] = { "scroll_documentation_down", "fallback" },
        },

        fuzzy = {
          implementation = "rust",
          sorts = {
            "exact",
            "score",
            "sort_text",
          },
        },

        completion = {
          keyword = {
            range = "full",
          },
          trigger = {
            show_in_snippet = false,
            show_on_keyword = true,
            show_on_trigger_character = true,
            show_on_blocked_trigger_characters = { " ", "\n", "\t" },
            show_on_accept_on_trigger_character = true,
            show_on_insert_on_trigger_character = true,
            show_on_x_blocked_trigger_characters = { "'", '"', "(" },
          },
          list = {
            max_items = 200,
            selection = {
              preselect = false,
              auto_insert = true,
            },
            cycle = {
              from_bottom = true,
              from_top = true,
            },
          },
          documentation = {
            auto_show = true,
            auto_show_delay_ms = 100,
            update_delay_ms = 50,
            treesitter_highlighting = true,
            window = {
              min_width = 10,
              max_width = 60,
              max_height = 20,
              border = "padded",
              winblend = 0,
              winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,CursorLine:BlinkCmpDocCursorLine,Search:None",
              scrollbar = true,
              direction_priority = {
                menu_north = { "e", "w", "n", "s" },
                menu_south = { "e", "w", "s", "n" },
              },
            },
          },
          accept = {
            create_undo_point = true,
            auto_brackets = {
              enabled = false,
            },
          },
          menu = {
            draw = {
              components = {
                label = {
                  width = { fill = true, max = 60 },
                  text = function(ctx)
                    local highlights_info = require("colorful-menu").blink_highlights(ctx)
                    if highlights_info ~= nil then
                      return highlights_info.label
                    else
                      return ctx.label
                    end
                  end,
                  highlight = function(ctx)
                    local highlights_info = require("colorful-menu").blink_highlights(ctx)
                    local highlights = {}
                    if highlights_info ~= nil then highlights = highlights_info.highlights end
                    for _, idx in ipairs(ctx.label_matched_indices) do
                      table.insert(highlights, { idx, idx + 1, group = "BlinkCmpLabelMatch" })
                    end
                    return highlights
                  end,
                },
              },
            },
          },
        },

        sources = {
          default = { "lsp", "path", "snippets", "buffer", "lazydev", "files" },
          providers = {
            lsp = {
              fallbacks = { "buffer" },
              override = {
                get_completions = function(self, context, callback)
                  return self:get_completions(context, function(response)
                    local filtered_items = {}
                    for _, item in ipairs(response.items) do
                      if not filter_kinds[tostring(item.kind)] then table.insert(filtered_items, item) end
                    end
                    response.items = filtered_items
                    callback(response)
                  end)
                end,
              },
            },
            buffer = {
              name = "Buffer",
              module = "blink.cmp.sources.buffer",
              min_keyword_length = 1,
              enabled = function()
                local clients = vim.lsp.get_clients({ bufnr = 0 })
                if #clients > 0 then return false end
                return true
              end,
            },
            snippets = {
              name = "Snippets",
              module = "blink.cmp.sources.snippets",
              score_offset = -2,
              opts = {
                friendly_snippets = false,
                search_paths = { vim.fn.stdpath("config") .. "/snippets_vscode" },
                global_snippets = { "all" },
                extended_filetypes = {},
                ignored_filetypes = {},
                get_filetype = function(context)
                  return vim.bo.filetype
                end,
              },
            },
            lazydev = {
              name = "LazyDev",
              module = "lazydev.integrations.blink",
              fallbacks = { "lsp" },
            },
            files = {
              name = "Files",
              module = "modules.completion.file-source",
              min_keyword_length = 0,
            },
          },
        },

        appearance = {
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

        signature = {
          enabled = true,
          window = {
            show_documentation = false,
          },
        },
      },
    },
    -- TODO: nvim-scissors
    {
      "smjonas/snippet-converter.nvim",
      -- enabled = false,
      cmd = { "ConvertSnippets" },
      config = function()
        local template = {
          sources = {
            snipmate = { vim.fn.stdpath("config") .. "/snippets_snipmate" },
          },
          output = {
            vscode = { vim.fn.stdpath("config") .. "/snippets_vscode" },
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

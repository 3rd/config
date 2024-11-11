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
      -- "3rd/blink.cmp",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "blink.cmp"),
      lazy = false,
      -- version = "nightly",
      -- version = "v0.*",
      build = "cargo build --release",
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
            enabled = true,
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
            draw = {
              align_to_component = "label", -- or 'none' to disable
              padding = 1,
              gap = 1,
              columns = { { "kind_icon" }, { "label", "label_description", gap = 1 } },
              -- Definitions for possible components to render. Each component defines:
              --   ellipsis: whether to add an ellipsis when truncating the text
              --   width: control the min, max and fill behavior of the component
              --   text function: will be called for each item
              --   highlight function: will be called only when the line appears on screen
              components = {
                kind_icon = {
                  ellipsis = false,
                  text = function(ctx)
                    return ctx.kind_icon .. " "
                  end,
                  highlight = function(ctx)
                    return "BlinkCmpKind" .. ctx.kind
                  end,
                },
                kind = {
                  ellipsis = false,
                  text = function(ctx)
                    return ctx.kind .. " "
                  end,
                  highlight = function(ctx)
                    return "BlinkCmpKind" .. ctx.kind
                  end,
                },
                label = {
                  width = { fill = true, max = 60 },
                  text = function(ctx)
                    return ctx.label .. (ctx.label_detail or "")
                  end,
                  highlight = function(ctx)
                    -- label and label details
                    local highlights = {
                      { 0, #ctx.label, group = ctx.deprecated and "BlinkCmpLabelDeprecated" or "BlinkCmpLabel" },
                    }
                    if ctx.label_detail then
                      table.insert(
                        highlights,
                        { #ctx.label, #ctx.label + #ctx.label_detail, group = "BlinkCmpLabelDetail" }
                      )
                    end

                    -- characters matched on the label by the fuzzy matcher
                    if ctx.label_matched_indices ~= nil then
                      for _, idx in ipairs(ctx.label_matched_indices) do
                        table.insert(highlights, { idx, idx + 1, group = "BlinkCmpLabelMatch" })
                      end
                    end

                    return highlights
                  end,
                },
                label_description = {
                  width = { max = 30 },
                  text = function(ctx)
                    return ctx.label_description or ""
                  end,
                  highlight = "BlinkCmpLabelDescription",
                },
              },
            },
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
            lsp = {
              fallback_for = { "lazydev" },
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
              fallback_for = { "lsp" },
              min_keyword_length = 1,
              enabled = function()
                local clients = vim.lsp.get_clients({ bufnr = 0 })
                if #clients > 0 then return false end
              end,
            },
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
            lazydev = {
              name = "LazyDev",
              module = "lazydev.integrations.blink",
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

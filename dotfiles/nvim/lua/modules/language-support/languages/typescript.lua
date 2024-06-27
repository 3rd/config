local filetypes = {
  "typescript",
  "typescriptreact",
  "javascript",
  "javascriptreact",
}

return lib.module.create({
  name = "language-support/languages/typescript",
  -- enabled = false,
  hosts = "*",
  plugins = {
    {
      "pmizio/typescript-tools.nvim",
      -- enabled = false,
      ft = filetypes,
      dependencies = {
        "nvim-lua/plenary.nvim",
        "neovim/nvim-lspconfig",
        "williamboman/mason.nvim",
        "dmmulroy/ts-error-translator.nvim",
      },
      config = function()
        local api = require("typescript-tools.api")

        local modules = lib.module.get_enabled_modules()
        local modules_with_on_attach_call = table.filter(modules, function(module)
          return ((module.hooks or {}).lsp or {}).on_attach_call ~= nil
        end)
        local modules_with_on_attach = table.filter(modules, function(module)
          return ((module.hooks or {}).lsp or {}).on_attach ~= nil
        end)

        local on_attach = function(client, bufnr)
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false

          for _, module in ipairs(modules_with_on_attach_call) do
            module.hooks.lsp.on_attach_call(client, bufnr)
          end

          client.handlers["textDocument/definition"] = function(err, result, ...)
            local patched_result = {}
            local target_path_line_map = {}

            -- filter line duplicates and external modules if there are internal definitions
            if (vim.tbl_islist(result) or type(result) == "table") and #result > 1 then
              local internal_entries = {}
              local external_entries = {}
              for _, v in ipairs(result) do
                local target_path = v.targetUri
                local target_line = v.targetRange.start.line

                if not target_path_line_map[target_path] then target_path_line_map[target_path] = {} end
                local mapped_target_lines = target_path_line_map[target_path]

                if not mapped_target_lines[target_line] then
                  mapped_target_lines[target_line] = true
                  if vim.fn.stridx(target_path, "node_modules") == -1 then
                    table.insert(internal_entries, v)
                  else
                    table.insert(external_entries, v)
                  end
                end
              end
              patched_result = vim.tbl_isempty(internal_entries) and external_entries or internal_entries
            else
              patched_result = result
            end

            vim.lsp.handlers["textDocument/definition"](err, patched_result, ...)
          end

          client.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
            require("ts-error-translator").translate_diagnostics(err, result, ctx, config)
            local filtered = api.filter_diagnostics({
              80006, -- This may be converted to an async function...
              80001, -- File is a CommonJS module; it may be converted to an ES module...
            })(err, result, ctx, config)
            return filtered
          end

          -- inlay hints
          if client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            local au_inlay_hints = vim.api.nvim_create_augroup("ts_inlay_hints", { clear = false })

            vim.api.nvim_create_autocmd({ "InsertLeave" }, {
              group = au_inlay_hints,
              buffer = bufnr,
              callback = function()
                vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
              end,
            })

            vim.api.nvim_create_autocmd({ "InsertEnter" }, {
              group = au_inlay_hints,
              buffer = bufnr,
              callback = function()
                vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
              end,
            })

            local mode = vim.api.nvim_get_mode().mode
            vim.lsp.inlay_hint.enable(mode == "n" or mode == "v", { bufnr = bufnr })
          end
        end

        -- hook.lsp.on_attach
        for _, module in ipairs(modules_with_on_attach) do
          on_attach = module.hooks.lsp.on_attach(on_attach)
        end

        require("typescript-tools").setup({
          settings = {
            -- tsserver_plugins = { "styled-components" }, -- npm i -g typescript-styled-plugin
            separate_diagnostic_server = true,
            publish_diagnostic_on = "insert_leave",
            expose_as_code_action = { "organize_imports", "remove_unused" },
            tsserver_max_memory = "auto",
            jsx_close_tag = {
              enable = true,
              filetypes = { "javascriptreact", "typescriptreact" },
            },
            complete_function_calls = true,
            tsserver_file_preferences = {
              -- allowIncompleteCompletions = true,
              -- allowRenameOfImportPath = true,
              -- allowTextChangesInNewFiles = true,
              -- disableLineTextInReferences = true,
              -- displayPartsForJSDoc = true,
              -- generateReturnInDocTemplate = true,
              -- importModuleSpecifier = "non-relative",
              -- importModuleSpecifierEnding = "auto",
              -- includeAutomaticOptionalChainCompletions = true,
              -- includeCompletionsForImportStatements = true,
              -- includeCompletionsWithClassMemberSnippets = true,
              -- includeCompletionsWithObjectLiteralMethodSnippets = true,
              -- includeCompletionsWithSnippetText = true,
              -- includeInlayEnumMemberValueHints = false,
              -- includeInlayFunctionLikeReturnTypeHints = false,
              -- includeInlayFunctionParameterTypeHints = false,
              -- includeInlayParameterNameHints = "all",
              -- includeInlayParameterNameHintsWhenArgumentMatchesName = false,
              -- includeInlayPropertyDeclarationTypeHints = false,
              -- includeInlayVariableTypeHints = true,
              -- includeInlayVariableTypeHintsWhenTypeMatchesName = false,
              -- jsxAttributeCompletionStyle = "auto",
              -- providePrefixAndSuffixTextForRename = true,
              -- provideRefactorNotApplicableReason = true,
              -- quotePreference = "auto",
              -- useLabelDetailsInCompletionEntries = true,
              includeInlayEnumMemberValueHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
              includeInlayFunctionParameterTypeHints = false,
              includeInlayParameterNameHints = "none",
              includeInlayParameterNameHintsWhenArgumentMatchesName = false,
              includeInlayPropertyDeclarationTypeHints = false,
              includeInlayVariableTypeHints = false,
              includeInlayVariableTypeHintsWhenTypeMatchesName = false,
            },
          },
          on_attach = on_attach,
        })

        vim.api.nvim_exec_autocmds("FileType", {})
      end,
    },
    {
      "axelvc/template-string.nvim",
      ft = filetypes,
      opts = {},
    },
    {
      "marilari88/twoslash-queries.nvim",
      ft = filetypes,
      opts = {
        highlight = "Type",
        multi_line = true,
      },
    },
  },
  hooks = {
    lsp = {
      on_attach_call = function(client, bufnr)
        local twoslash_clients = {
          "tsserver",
          "vtsls",
          "typescript-tools",
        }
        if not vim.tbl_contains(twoslash_clients, client.name) then return end

        require("twoslash-queries").attach(client, bufnr)
        lib.map.map(
          "n",
          "<leader>?",
          ":TwoslashQueriesInspect<CR>",
          { buffer = bufnr, desc = "Add type inspect comment" }
        )
      end,
    },
  },
})

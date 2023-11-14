local filetypes = {
  "typescript",
  "typescriptreact",
  "javascript",
  "javascriptreact",
}

return lib.module.create({
  -- enabled = false,
  name = "language-support/languages/typescript",
  plugins = {
    {
      "pmizio/typescript-tools.nvim",
      -- event = "VeryLazy",
      ft = filetypes,
      dependencies = {
        "nvim-lua/plenary.nvim",
        "neovim/nvim-lspconfig",
        "williamboman/mason.nvim",
      },
      config = function()
        -- local api = require("typescript-tools.api")
        -- local mason_registry = require("mason-registry")
        -- local tsserver_path = mason_registry.get_package("typescript-language-server"):get_install_path()

        require("typescript-tools").setup({
          settings = {
            -- tsserver_path = tsserver_path .. "/node_modules/typescript/lib/tsserver.js",
            separate_diagnostic_server = true,
            publish_diagnostic_on = "insert_leave",
            expose_as_code_action = { "organize_imports", "remove_unused" },
            tsserver_max_memory = 8096, -- 4096 | "auto"
            -- complete_function_calls = false,
            -- handlers = {
            --   ["textDocument/publishDiagnostics"] = api.filter_diagnostics(
            --     -- Ignore 'This may be converted to an async function' diagnostics.
            --     -- { 80006 }
            --     {}
            --   ),
            -- },
            -- tsserver_plugins = { "styled-components" }, -- npm i -g typescript-styled-plugin
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
              includeInlayParameterNameHints = "literal",
              includeInlayParameterNameHintsWhenArgumentMatchesName = false,
              includeInlayVariableTypeHintsWhenTypeMatchesName = false,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayFunctionLikeReturnTypeHints = false,
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayEnumMemberValueHints = true,
            },
          },
          -- TODO: export this to other modules
          on_attach = function(client, bufnr)
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false

            client.handlers["textDocument/definition"] = function(err, result, ...)
              local patched_result = {}
              if (vim.tbl_islist(result) or type(result) == "table") and #result > 1 then
                for _, v in ipairs(result) do
                  if vim.fn.stridx(v.targetUri, "node_modules") == -1 then table.insert(patched_result, v) end
                end
              else
                patched_result = result
              end
              vim.lsp.handlers["textDocument/definition"](err, patched_result, ...)
            end

            require("twoslash-queries").attach(client, bufnr)
            lib.map.map("n", "<leader>?", ":TwoslashQueriesInspect<CR>", { buffer = bufnr })
          end,
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
})

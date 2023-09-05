return lib.module.create({
  -- enabled = false,
  name = "language-support/languages/typescript",
  plugins = {
    {
      "pmizio/typescript-tools.nvim",
      ft = {
        "typescript",
        "typescriptreact",
        "javascript",
        "javascriptreact",
      },
      -- event = "VeryLazy",
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
            separate_diagnostic_server = false,
            publish_diagnostic_on = "insert_leave",
            expose_as_code_action = { "fix_all", "add_missing_imports", "remove_unused" },
            tsserver_max_memory = 4096, -- or "auto"
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
            },
            tsserver_format_options = {
              -- indentSwitchCase = true,
              -- insertSpaceAfterCommaDelimiter = true,
              -- insertSpaceAfterConstructor = false,
              -- insertSpaceAfterFunctionKeywordForAnonymousFunctions = true,
              -- insertSpaceAfterKeywordsInControlFlowStatements = true,
              -- insertSpaceAfterOpeningAndBeforeClosingEmptyBraces = true,
              -- insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBraces = false,
              -- insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces = true,
              -- insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets = false,
              -- insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis = false,
              -- insertSpaceAfterOpeningAndBeforeClosingTemplateStringBraces = false,
              -- insertSpaceAfterSemicolonInForStatements = true,
              -- insertSpaceAfterTypeAssertion = false,
              -- insertSpaceBeforeAndAfterBinaryOperators = true,
              -- insertSpaceBeforeFunctionParenthesis = false,
              -- placeOpenBraceOnNewLineForControlBlocks = false,
              -- placeOpenBraceOnNewLineForFunctions = false,
              -- semicolons = "ignore",
            },
          },
        })

        vim.api.nvim_exec_autocmds("FileType", {})
      end,
    },
    {
      "axelvc/template-string.nvim",
      ft = {
        "typescript",
        "typescriptreact",
        "javascript",
        "javascriptreact",
      },
      opts = {},
    },
  },
})

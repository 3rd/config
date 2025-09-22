return {
  root_dir = function(bufnr, on_dir)
    local root_markers = { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }
    root_markers = vim.list_extend(root_markers, { ".git" })
    local project_root = vim.fs.root(bufnr, root_markers) or vim.fn.getcwd()
    on_dir(project_root)
  end,
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
  flags = {
    allow_incremental_sync = false,
    debounce_text_changes = 5000,
  },
  -- https://github.com/yioneko/vtsls/blob/main/packages/service/configuration.schema.json
  settings = {
    complete_function_calls = true,
    vtsls = {
      enableMoveToFileCodeAction = true,
      autoUseWorkspaceTsdk = true,
      experimental = {
        maxInlayHintLength = 30,
        completion = {
          enableServerSideFuzzyMatch = true,
          entriesLimit = 150,
        },
      },
    },
    typescript = {
      format = { enable = false },
      tsserver = {
        maxTsServerMemory = "auto",
        -- experimental = { enableProjectDiagnostics = true }, -- this breaks vts by opening unrelated files
      },
      preferences = {
        includePackageJsonAutoImports = "off",
        useAliasesForRenames = true,
      },
      suggest = {
        completeFunctionCalls = true,
      },
      inlayHints = {
        enumMemberValues = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        variableTypes = { enabled = true },
      },
      updateImportsOnFileMove = { enabled = "always" },
    },
  },
}

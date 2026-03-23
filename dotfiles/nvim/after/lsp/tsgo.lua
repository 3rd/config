-- defaults
-- {
--   "compilerOptions": {
--     "checkJs": false,
--     "skipLibCheck": true,
--     "disableReferencedProjectLoad": true,
--     "disableSolutionSearching": true
--   },
--   "include": ["src"],
-- }

-- tsgo/tsc subdir mix
-- {
--   "extends": "../tsconfig.json",
--   "compilerOptions": {
--     "baseUrl": null,
--     "paths": {
--       "@/*": ["./../src/*"]
--     }
--   }
-- }

local tsgo_bin = vim.fn.exepath("tsgo")
local native_preview = {
  customConfigFileName = "tsconfig.local.json",
}

local inlay_hints = {
  parameterNames = { enabled = "literals", suppressWhenArgumentMatchesName = true },
  parameterTypes = { enabled = true },
  variableTypes = { enabled = true },
  propertyDeclarationTypes = { enabled = true },
  functionLikeReturnTypes = { enabled = true },
  enumMemberValues = { enabled = true },
}

return {
  cmd = { tsgo_bin, "--lsp", "--stdio" },
  enabled = vim.fn.executable(tsgo_bin) == 1,
  settings = {
    javascript = {
      format = { enable = false },
      ["native-preview"] = native_preview,
      preferences = {
        includePackageJsonAutoImports = "off",
        useAliasesForRenames = true,
      },
      inlayHints = inlay_hints,
    },
    typescript = {
      format = { enable = false },
      ["native-preview"] = native_preview,
      preferences = {
        includePackageJsonAutoImports = "off",
        useAliasesForRenames = true,
      },
      inlayHints = inlay_hints,
      updateImportsOnFileMove = {
        enabled = "always",
      },
    },
  },
}

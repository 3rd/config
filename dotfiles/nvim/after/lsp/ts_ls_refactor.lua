-- tsc 7 serves no refactor code actions, so ts_ls runs beside it for refactors only. TypeScript 7 ships no tsserver,
-- so projects pinned to it fall back to the installer's TypeScript 6.
local registry = require("lib/installer/registry")

local REFACTOR = vim.lsp.protocol.CodeActionKind.Refactor

local keep_refactor_capabilities = function(client)
  local capabilities = client.server_capabilities
  client.server_capabilities = {
    textDocumentSync = capabilities.textDocumentSync,
    executeCommandProvider = capabilities.executeCommandProvider,
    codeActionProvider = {
      codeActionKinds = { REFACTOR },
      resolveProvider = vim.tbl_get(capabilities, "codeActionProvider", "resolveProvider"),
    },
  }
end

local request_only_refactors = function(client)
  local request = client.request
  client.request = function(self, method, params, handler, bufnr)
    if method == "textDocument/codeAction" then
      local context = vim.tbl_extend("force", params.context, { only = { REFACTOR } })
      params = vim.tbl_extend("force", params, { context = context })
    end
    return request(self, method, params, handler, bufnr)
  end
end

local config = vim.deepcopy(vim.lsp.config.ts_ls)
config.on_attach = nil

return vim.tbl_deep_extend("force", config, {
  enabled = registry.is_installed("tsserver"),
  init_options = {
    tsserver = { fallbackPath = registry.get_executable_path("tsserver") },
  },
  on_init = { keep_refactor_capabilities, request_only_refactors },
  handlers = {
    ["textDocument/publishDiagnostics"] = function() end,
  },
})

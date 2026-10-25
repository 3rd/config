require("lib")

local CREATED = vim.lsp.protocol.FileChangeType.Created
local CHANGED = vim.lsp.protocol.FileChangeType.Changed
local DELETED = vim.lsp.protocol.FileChangeType.Deleted
local config = dofile(vim.api.nvim_get_runtime_file("after/lsp/tsc.lua", false)[1])
local clients = {
  [1] = { name = "tsc", workspace_folders = { { uri = vim.uri_from_fname("/work/app"), name = "app" } } },
  [2] = { name = "gopls" },
}
vim.lsp.get_client_by_id = function(id)
  return clients[id]
end

local registered
vim.lsp.handlers["client/registerCapability"] = function(_, params)
  registered = params
end

config.handlers["client/registerCapability"](nil, {
  registrations = {
    {
      id = "watchers",
      method = "workspace/didChangeWatchedFiles",
      registerOptions = {
        watchers = {
          { globPattern = "/work/app/**/*" },
          { globPattern = "/work/app/node_modules/**/*" },
          { globPattern = "/work/application/**/*" },
          { globPattern = "/work/other/node_modules/**/*" },
          { globPattern = { baseUri = vim.uri_from_fname("/work"), pattern = "**/*" } },
          {
            globPattern = { baseUri = { uri = vim.uri_from_fname("/work/app/src"), name = "src" }, pattern = "*.ts" },
          },
          { globPattern = "**/*.json" },
        },
      },
    },
    { id = "configuration", method = "workspace/didChangeConfiguration" },
  },
}, { client_id = 1 })

local kept = vim.tbl_map(function(watcher)
  return type(watcher.globPattern) == "table" and watcher.globPattern.pattern or watcher.globPattern
end, registered.registrations[1].registerOptions.watchers)
assert(
  vim.deep_equal(kept, { "/work/app/**/*", "/work/app/node_modules/**/*", "*.ts", "**/*.json" }),
  vim.inspect(kept)
)
assert(registered.registrations[2].method == "workspace/didChangeConfiguration")

local sent = {}
local client = {
  notify = function(_, method, params)
    table.insert(sent, { method = method, params = params })
    return true
  end,
}
config.on_init(client)
client:notify("workspace/didChangeWatchedFiles", {
  changes = {
    { uri = "file:///work/app/a.ts", type = CREATED },
    { uri = "file:///work/app/b.ts", type = CHANGED },
    { uri = "file:///work/app/c.ts", type = DELETED },
  },
})
assert(
  vim.deep_equal(sent[1].params.changes, {
    { uri = "file:///work/app/a.ts", type = CHANGED },
    { uri = "file:///work/app/a.ts", type = CREATED },
    { uri = "file:///work/app/b.ts", type = CHANGED },
    { uri = "file:///work/app/c.ts", type = DELETED },
  }),
  "a created file is also reported changed so tsc reloads a replaced file"
)
client:notify("textDocument/didSave", { textDocument = { uri = "file:///work/app/a.ts" } })
assert(sent[2].method == "textDocument/didSave")

local pulled
vim.lsp.handlers["textDocument/diagnostic"] = function(_, result)
  pulled = result
end
package.loaded["ts-error-translator"] = {
  config = { servers = { "tsc" } },
  parse_errors = function(message)
    return { { improvedError = { body = "plain: " .. message } } }
  end,
}
require("modules/language-support/lspconfig").setup()

vim.lsp.handlers["textDocument/diagnostic"](nil, { kind = "full", items = { { code = 2322, message = "m" } } }, {
  client_id = 1,
})
assert(pulled.items[1].message == "plain: TS2322: m", "pulled tsc diagnostics must be translated")
vim.lsp.handlers["textDocument/diagnostic"](nil, { kind = "full", items = { { code = 1, message = "m" } } }, {
  client_id = 2,
})
assert(pulled.items[1].message == "m", "other servers' diagnostics must stay untouched")

package.loaded["ts-error-translator"] = nil
package.preload["ts-error-translator"] = function()
  error("ts-error-translator is not installed")
end
pulled = nil
vim.lsp.handlers["textDocument/diagnostic"](nil, { kind = "full", items = { { code = 2322, message = "m" } } }, {
  client_id = 1,
})
assert(pulled and pulled.items[1].message == "m", "diagnostics must still arrive when the translator cannot load")

vim.lsp.config("ts_ls", { cmd = { "typescript-language-server", "--stdio" }, on_attach = function() end })
local refactor_config = dofile(vim.api.nvim_get_runtime_file("after/lsp/ts_ls_refactor.lua", false)[1])
assert(refactor_config.on_attach == nil, "ts_ls attach commands must not rebind LspTypescriptSourceAction")

local refactor_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(refactor_buf, "/work/app/a.ts")
refactor_config.handlers["textDocument/publishDiagnostics"](nil, {
  uri = vim.uri_from_bufnr(refactor_buf),
  diagnostics = {
    { message = "m", range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 1 } } },
  },
}, { client_id = 1 })
assert(#vim.diagnostic.get(refactor_buf) == 0, "only tsc may publish diagnostics")

local requests = {}
local refactor_client = {
  name = "ts_ls_refactor",
  server_capabilities = {
    textDocumentSync = { openClose = true, change = 2 },
    hoverProvider = true,
    completionProvider = { triggerCharacters = { "." } },
    renameProvider = true,
    executeCommandProvider = { commands = { "_typescript.applyRefactoring" } },
    codeActionProvider = {
      codeActionKinds = { "quickfix", "refactor", "source.organizeImports.ts" },
      resolveProvider = true,
    },
  },
  request = function(_, method, params)
    table.insert(requests, { method = method, params = params })
    return true, #requests
  end,
}
for _, on_init in ipairs(refactor_config.on_init) do
  on_init(refactor_client)
end
assert(
  vim.deep_equal(refactor_client.server_capabilities, {
    textDocumentSync = { openClose = true, change = 2 },
    executeCommandProvider = { commands = { "_typescript.applyRefactoring" } },
    codeActionProvider = { codeActionKinds = { "refactor" }, resolveProvider = true },
  }),
  vim.inspect(refactor_client.server_capabilities)
)

refactor_client:request("textDocument/codeAction", { context = { diagnostics = { { message = "d" } } } })
refactor_client:request("textDocument/hover", { position = { line = 0, character = 0 } })
assert(
  vim.deep_equal(requests[1].params.context, { diagnostics = { { message = "d" } }, only = { "refactor" } }),
  "ts_ls must only compute refactors so its quickfixes do not duplicate tsc's"
)
assert(vim.deep_equal(requests[2].params, { position = { line = 0, character = 0 } }))

local typescript = require("modules/language-support/languages/typescript")
local source_action_only
vim.lsp.buf.code_action = function(opts)
  source_action_only = opts.context.only
end
typescript.hooks.lsp.on_attach({
  name = "primary",
  server_capabilities = { codeActionProvider = { codeActionKinds = { "quickfix", "source.organizeImports" } } },
}, refactor_buf)
typescript.hooks.lsp.on_attach(refactor_client, refactor_buf)
vim.api.nvim_buf_call(refactor_buf, function()
  vim.cmd("LspTypescriptSourceAction")
end)
assert(
  vim.deep_equal(source_action_only, { "source.organizeImports" }),
  "a refactor-only client attaching later must not take over LspTypescriptSourceAction"
)

print(
  "ok: tsc keeps workspace watchers, reports created files as changed too, and gets translated pull diagnostics;"
    .. " ts_ls_refactor serves refactors only"
)

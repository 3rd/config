local installer = require("lib/installer")
local jsonls_bin = installer.registry.get_executable_path("vscode-langservers-extracted")

local schemas = {}
local ok, schemastore = pcall(require, "schemastore")
if ok then schemas = schemastore.json.schemas() end

return {
  cmd = { jsonls_bin, "--stdio" },
  enabled = installer.registry.is_installed("vscode-langservers-extracted"),
  filetypes = { "json", "jsonc" },
  root_markers = { ".git" },
  init_options = {
    provideFormatter = true,
  },
  settings = {
    json = {
      schemas = schemas,
      validate = { enable = true },
    },
  },
}

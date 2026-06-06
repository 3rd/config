local installer = require("lib/installer")

local servers = {
  "ast_grep",
  "bashls",
  "clangd",
  "csharp_ls",
  "cssls",
  "dockerls",
  "gopls",
  "html",
  "jsonls",
  "lua_ls",
  "nil_ls",
  "rust_analyzer",
  "basedpyright",
  "tailwindcss",
  "eslint",
  -- "tsgo",
  "ts_ls",
  -- "vtsls",
  "yamlls",
  "zls",
}

if installer.resolve("cssmodules-language-server") then table.insert(servers, "cssmodules_ls") end

return servers

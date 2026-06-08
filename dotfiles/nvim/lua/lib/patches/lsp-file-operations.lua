local M = {}

local handler_modules = {
  "lsp-file-operations.will-rename",
  "lsp-file-operations.did-rename",
  "lsp-file-operations.will-create",
  "lsp-file-operations.did-create",
  "lsp-file-operations.will-delete",
  "lsp-file-operations.did-delete",
}

local get_active_clients
get_active_clients = function()
  if vim.lsp.get_active_clients and vim.lsp.get_active_clients ~= get_active_clients then
    return vim.lsp.get_active_clients()
  end
  return vim.lsp.get_clients()
end

local with_active_clients_compat = function(callback)
  return function(...)
    local original_get_active_clients = vim.lsp.get_active_clients
    vim.lsp.get_active_clients = original_get_active_clients or get_active_clients

    local ok, result = pcall(callback, ...)
    vim.lsp.get_active_clients = original_get_active_clients

    if not ok then error(result, 0) end
    return result
  end
end

local patch_handler = function(module_name)
  local handler = require(module_name)
  if handler.__active_clients_compat then return end

  handler.callback = with_active_clients_compat(handler.callback)
  handler.__active_clients_compat = true
end

M.setup = function(opts)
  local lsp_file_operations = require("lsp-file-operations")
  lsp_file_operations.setup(opts)

  -- compat for antosha417/nvim-lsp-file-operations#51 until upstream uses get_clients.
  for _, module_name in ipairs(handler_modules) do
    patch_handler(module_name)
  end
end

return M

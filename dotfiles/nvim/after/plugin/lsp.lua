vim.diagnostic.config({
  update_in_insert = false,
  severity_sort = true,
})

-- workaround: neovim 0.12 nightly crashes on dynamic registration of
-- methods not in _request_name_to_server_capability (e.g. eslint custom methods).
-- filter them out before they reach _register_dynamic. see neovim#37166
if not vim.g._lsp_register_capability_filter_patched then
  local orig_register = vim.lsp.handlers["client/registerCapability"]
  if type(orig_register) == "function" then
    vim.lsp.handlers["client/registerCapability"] = function(err, params, ctx)
      if type(params) ~= "table" or not vim.islist(params.registrations) then
        return orig_register(err, params, ctx)
      end

      local known = vim.lsp.protocol and vim.lsp.protocol._request_name_to_server_capability
      if type(known) ~= "table" then
        return orig_register(err, params, ctx)
      end

      local registrations = vim.tbl_filter(function(reg)
        return type(reg) == "table" and known[reg.method] ~= nil
      end, params.registrations)
      if #registrations == 0 then return vim.NIL end

      params.registrations = registrations
      return orig_register(err, params, ctx)
    end
    vim.g._lsp_register_capability_filter_patched = true
  end
end

vim.lsp.config("*", {
  root_markers = { ".root", ".git" },
  capabilities = require("blink.cmp").get_lsp_capabilities({
    workspace = {
      -- https://github.com/neovim/neovim/issues/23291
      didChangeWatchedFiles = { dynamicRegistration = false },
    },
    textDocument = {
      completion = {
        completionItem = {
          snippetSupport = true,
          resolveSupport = {
            properties = { "documentation", "detail", "additionalTextEdits" },
          },
        },
      },
    },
  }),
})

local overrides = {
  formatting = {
    enable = { "eslint" },
    disable = { "html", "vtsls", "ts_ls" },
  },
}

local enabled_modules = lib.module.get_enabled_modules()
local modules_with_capabilities = table.filter(enabled_modules, function(module)
  return ((module.hooks or {}).lsp or {}).capabilities ~= nil
end)
local modules_with_on_attach = table.filter(enabled_modules, function(module)
  return ((module.hooks or {}).lsp or {}).on_attach ~= nil
end)

local setup_lsp_buffer = function(bufnr)
  -- because fuck consistency
  local disable_default_lsp_mappings = function()
    local opts = { buffer = bufnr }
    vim.keymap.del("n", "K", opts)
    vim.keymap.del("n", "grr", opts)
    vim.keymap.del("n", "grn", opts)
    vim.keymap.del("n", "gra", opts)
    vim.keymap.del("n", "gri", opts)
    vim.keymap.del("n", "grt", opts)
    vim.keymap.del("n", "gO", opts)
  end
  pcall(disable_default_lsp_mappings)

  -- mappings
  for _, mapping in ipairs(require("config/mappings").lsp) do
    local mode, lhs, rhs, opts_or_desc = mapping[1], mapping[2], mapping[3], mapping[4]
    local opts = {}
    if lib.is.string(opts_or_desc) then
      opts.desc = opts_or_desc
    elseif lib.is.table(opts_or_desc) then
      opts = table.clone(opts_or_desc)
    end
    opts.buffer = bufnr
    lib.map.map(mode, lhs, rhs, opts)
  end
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf
    local client_id = args.data and args.data.client_id
    local client = client_id and vim.lsp.get_client_by_id(client_id) or nil

    if not vim.b[bufnr]._lsp_buffer_initialized then
      setup_lsp_buffer(bufnr)
      vim.b[bufnr]._lsp_buffer_initialized = true
    end

    if not client then return end

    -- hook.lsp.on_attach
    for _, module in ipairs(modules_with_on_attach) do
      module.hooks.lsp.on_attach(client, bufnr)
    end

    -- hook.lsp.capabilities
    for _, module in ipairs(modules_with_capabilities) do
      client.server_capabilities = module.hooks.lsp.capabilities(client.server_capabilities)
    end

    -- lsp formatting
    if vim.tbl_contains(overrides.formatting.enable, client.name) then
      client.server_capabilities.documentFormattingProvider = true
    elseif vim.tbl_contains(overrides.formatting.disable, client.name) then
      client.server_capabilities.documentFormattingProvider = false
    end
  end,
})

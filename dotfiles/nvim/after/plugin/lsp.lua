vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
  update_in_insert = false,
  severity_sort = true,
})

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

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)

    -- because fuck consistency
    local disable_default_lsp_mappings = function()
      vim.keymap.del("n", "K", { buffer = args.buf })
      vim.keymap.del("n", "grr")
      vim.keymap.del("n", "grn")
      vim.keymap.del("n", "gra")
      vim.keymap.del("n", "gri")
      vim.keymap.del("n", "grt")
      vim.keymap.del("n", "gO")
    end
    pcall(disable_default_lsp_mappings)

    -- mappings
    for _, mapping in ipairs(require("config/mappings").lsp) do
      local mode, lhs, rhs, opts_or_desc = mapping[1], mapping[2], mapping[3], mapping[4]
      local opts = lib.is.string(opts_or_desc) and { desc = opts_or_desc } or opts_or_desc or {}
      opts.buffer = args.buf
      lib.map.map(mode, lhs, rhs, opts)
    end

    if not client then return end

    -- hook.lsp.on_attach
    local modules = lib.module.get_enabled_modules()
    local modules_with_capabilities = table.filter(modules, function(module)
      return ((module.hooks or {}).lsp or {}).capabilities ~= nil
    end)
    local modules_with_on_attach = table.filter(modules, function(module)
      return ((module.hooks or {}).lsp or {}).on_attach ~= nil
    end)
    for _, module in ipairs(modules_with_on_attach) do
      module.hooks.lsp.on_attach(client, args.buf)
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

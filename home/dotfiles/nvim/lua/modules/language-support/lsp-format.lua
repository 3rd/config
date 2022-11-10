local config = {
  exclude = { "html", "tsserver", "jsonls" },
}

local setup = function()
  local lsp_format = require("lsp-format")
  lsp_format.setup(require("modules/language-support/lsp-format").export.config)

  vim.cmd([[cabbrev wq execute "lua vim.lsp.buf.format()" <bar> wq]])
end

local on_attach = function(client)
  local exclude =
    require("modules/language-support/lsp-format").export.config.exclude
  if not vim.tbl_contains(exclude, client.name) then
    require("lsp-format").on_attach(client)
  end
end

return require("lib").module.create({
  name = "language-support/lsp-format",
  plugins = {
    {
      "lukas-reineke/lsp-format.nvim",
      config = setup,
    },
  },
  hooks = {
    lsp_on_attach = on_attach,
  },
  export = {
    config = config,
  },
})

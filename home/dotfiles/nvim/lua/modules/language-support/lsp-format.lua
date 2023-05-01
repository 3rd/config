local config = {
  exclude = {},
}

local setup = function()
  local lsp_format = require("lsp-format")
  lsp_format.setup(config)

  vim.cmd([[cabbrev wq execute "lua vim.lsp.buf.format()" <bar> wq]])
end

return lib.module.create({
  name = "language-support/lsp-format",
  plugins = {
    {
      "lukas-reineke/lsp-format.nvim",
      config = setup,
    },
  },
  hooks = {
    lsp = {
      on_attach_call = function(client)
        require("lsp-format").on_attach(client)
      end,
    },
  },
})

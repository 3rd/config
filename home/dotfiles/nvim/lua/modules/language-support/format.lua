return lib.module.create({
  name = "language-support/format",
  plugins = {
    {
      "lukas-reineke/lsp-format.nvim",
      config = function()
        local lsp_format = require("lsp-format")
        lsp_format.setup()
        vim.cmd([[cabbrev wq execute "lua vim.lsp.buf.format()" <bar> wq]])
      end,
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

return lib.module.create({
  name = "language-support/mason",
  -- enabled = false,
  hosts = "*",
  plugins = {
    {
      "williamboman/mason.nvim",
      lazy = false,
      dependencies = {
        "williamboman/mason-lspconfig.nvim",
      },
      config = function()
        local mason = require("mason")
        local mason_lspconfig = require("mason-lspconfig")
        mason.setup()

        mason_lspconfig.setup({
          ensure_installed = {
            "astro",
            "bashls",
            "cssls",
            "cssmodules_ls",
            "dockerls",
            -- "eslint",
            "golangci_lint_ls",
            "gopls",
            "html",
            "jsonls",
            "vimls",
            "yamlls",
            "tailwindcss",
            "vtsls",
            -- "vuels",
          },
          automatic_installation = true,
        })
      end,
    },
  },
})

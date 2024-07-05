return lib.module.create({
  name = "language-support/mason",
  hosts = "*",
  plugins = {
    {
      "williamboman/mason.nvim",
      lazy = false,
      dependencies = {
        "williamboman/mason-lspconfig.nvim",
        "WhoIsSethDaniel/mason-tool-installer.nvim",
      },
      config = function()
        local mason = require("mason")
        local mason_lspconfig = require("mason-lspconfig")
        local mason_tool_installer = require("mason-tool-installer")

        mason.setup()

        mason_lspconfig.setup({
          ensure_installed = {
            "astro",
            "bashls",
            "cssls",
            "cssmodules_ls",
            "dockerls",
            "eslint",
            "golangci_lint_ls",
            "gopls",
            "html",
            "jsonls",
            "tailwindcss",
            "vimls",
            "vuels",
            "yamlls",
            "vtsls",
          },
          automatic_installation = true,
        })

        mason_tool_installer.setup({
          ensure_installed = vim.tbl_extend("force", {
            -- linters (+host: clangd, statix)
            "alex",
            "cpplint",
            -- formatters
            "fixjson",
            "prettierd",
            "rustywind",
          }, require("jit").arch ~= "arm64" and { "selene" } or {}),
        })
      end,
    },
  },
})

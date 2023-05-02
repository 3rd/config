local setup = function(on_attach)
  local lib = require("lib")
  local null_ls = require("null-ls")
  local util = require("lspconfig.util")

  local paths = {
    stylua_config = vim.fn.expand("~/.config/nvim/linters/stylua.toml"),
    eslint_config = vim.fn.expand("~/.config/nvim/linters/eslint/dist/main.js"),
    eslint_node_modules = vim.fn.expand("~/.config/nvim/linters/eslint/node_modules"),
    prettier_config = vim.fn.expand("~/.config/nvim/linters/prettier.json"),
  }

  local sources = {
    null_ls.builtins.formatting.stylua.with({
      extra_args = { "--config-path", paths.stylua_config },
    }),
    null_ls.builtins.diagnostics.statix,
    null_ls.builtins.diagnostics.deadnix,
    null_ls.builtins.code_actions.statix,
    null_ls.builtins.formatting.nixfmt.with({ extra_args = { "--width", "80" } }),
    null_ls.builtins.diagnostics.shellcheck,
    null_ls.builtins.formatting.shfmt.with({
      args = { "-i", "2", "-ci", "-bn", "-filename", "$FILENAME" },
    }),
    null_ls.builtins.formatting.shellharden,
    null_ls.builtins.formatting.fish_indent,
    null_ls.builtins.formatting.gofmt,
    null_ls.builtins.formatting.goimports,
    null_ls.builtins.formatting.rustfmt,
    null_ls.builtins.formatting.prettierd.with({
      env = { PRETTIERD_DEFAULT_CONFIG = paths.prettier_config },
    }),
    null_ls.builtins.formatting.rustywind.with({
      filetypes = { "astro", "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte", "html" },
    }),
    null_ls.builtins.diagnostics.cppcheck,
    null_ls.builtins.formatting.clang_format,
    null_ls.builtins.formatting.fixjson,
    null_ls.builtins.diagnostics.gitlint,
    -- null_ls.builtins.code_actions.gitsigns.with({
    --   config = {
    --     filter_actions = function(title)
    --       return title:lower():match("blame") == nil
    --     end,
    --   },
    -- }),
  }

  local config = {
    debug = false,
    border = "rounded",
    log_level = "warn",
    on_attach = on_attach,
    root_dir = util.root_pattern(".root", "package.json", ".git") or lib.buffer.current.get_directory(),
    sources = sources,
  }

  null_ls.setup(config)
end

return lib.module.create({
  name = "null-ls",
  plugins = {
    {
      "jose-elias-alvarez/null-ls.nvim",
      event = "VeryLazy",
      dependencies = {
        "neovim/nvim-lspconfig",
        "nvim-lua/plenary.nvim",
      },
    },
  },
  hooks = {
    lsp = { on_attach = setup },
  },
})

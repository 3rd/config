local setup = function()
  local null_ls = require("null-ls")
  local util = require("lspconfig.util")

  local paths = {
    stylua_config = lib.path.resolve_config("linters/stylua.toml"),
    eslint_config = lib.path.resolve_config("linters/eslint/dist/main.js"),
    eslint_node_modules = lib.path.resolve_config("linters/eslint/node_modules"),
    prettier_config = lib.path.resolve_config("linters/prettier.json"),
  }

  local sources = {
    null_ls.builtins.formatting.stylua.with({
      extra_args = { "--config-path", paths.stylua_config },
    }),
    null_ls.builtins.diagnostics.statix,
    null_ls.builtins.diagnostics.deadnix,
    null_ls.builtins.code_actions.statix,
    null_ls.builtins.formatting.nixfmt.with({ extra_args = { "--width", "80" } }),
    -- null_ls.builtins.diagnostics.shellcheck,
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
      filetypes = {
        "javascript",
        "javascriptreact",
        "typescript",
        "typescriptreact",
        "vue",
        "css",
        "scss",
        "less",
        "html",
        "json",
        "jsonc",
        "yaml",
        -- "markdown",
        -- "markdown.mdx",
        "graphql",
        "handlebars",
        "astro",
      },
    }),
    null_ls.builtins.formatting.rustywind.with({
      filetypes = { "astro", "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte", "html" },
    }),
    null_ls.builtins.diagnostics.cppcheck,
    null_ls.builtins.formatting.clang_format,
    null_ls.builtins.formatting.fixjson,
    null_ls.builtins.diagnostics.gitlint,
    null_ls.builtins.code_actions.refactoring,
  }

  null_ls.setup({
    -- debug = true,
    border = "rounded",
    log_level = "warn",
    on_attach = function(client, bufnr)
      -- mappings
      for _, mapping in ipairs(require("config/mappings").lsp) do
        local mode, lhs, rhs, opts_or_desc = mapping[1], mapping[2], mapping[3], mapping[4]
        local opts = lib.is.string(opts_or_desc) and { desc = opts_or_desc } or opts_or_desc or {}
        opts.buffer = bufnr
        lib.map.map(mode, lhs, rhs, opts)
      end

      require("lsp-format").on_attach(client)
    end,
    root_dir = util.root_pattern(".root", "package.json", ".git") or lib.buffer.current.get_directory(),
    sources = sources,
  })

  vim.keymap.set(
    { "n", "v" },
    "<leader>ar",
    ":lua require('refactoring').select_refactor()<CR>",
    { noremap = true, silent = true, expr = false }
  )
end

return lib.module.create({
  name = "null-ls",
  plugins = {
    {
      "jose-elias-alvarez/null-ls.nvim",
      event = { "BufReadPost", "BufAdd", "BufNewFile" },
      dependencies = {
        "neovim/nvim-lspconfig",
        "nvim-lua/plenary.nvim",
        "ThePrimeagen/refactoring.nvim",
      },
      config = setup,
    },
  },
})

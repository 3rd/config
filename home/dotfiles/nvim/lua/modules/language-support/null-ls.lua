local setup = function(on_attach)
  local lib = require("lib")
  local null_ls = require("null-ls")
  local util = require("lspconfig.util")

  local paths = {
    stylua_config = vim.fn.expand("~/.config/nvim/linters/stylua.toml"),
    revive_config = vim.fn.expand("~/.config/nvim/linters/revive.toml"),
    eslint_d_binary = vim.fn.expand("~/.npm/global/bin/eslint_d"),
    eslint_config = vim.fn.expand("~/.config/nvim/linters/eslint/dist/main.js"),
    eslint_node_modules = vim.fn.expand("~/.config/nvim/linters/eslint/node_modules"),
    prettier_config = vim.fn.expand("~/.config/nvim/linters/prettier.json"),
  }

  local sources = {
    null_ls.builtins.formatting.stylua.with({ extra_args = { "--config-path", paths.stylua_config } }),
    null_ls.builtins.diagnostics.statix,
    null_ls.builtins.diagnostics.deadnix,
    null_ls.builtins.code_actions.statix,
    null_ls.builtins.formatting.nixfmt.with({ extra_args = { "--width", "80" } }),
    null_ls.builtins.diagnostics.shellcheck,
    null_ls.builtins.formatting.shfmt.with({ args = { "-i", "2", "-ci", "-bn", "-filename", "$FILENAME" } }),
    null_ls.builtins.formatting.shellharden,
    null_ls.builtins.formatting.fish_indent,
    null_ls.builtins.diagnostics.revive.with({
      args = { "-config", paths.revive_config, "-formatter", "json", "./..." },
    }),
    null_ls.builtins.formatting.gofmt,
    null_ls.builtins.formatting.goimports,
    null_ls.builtins.formatting.rustfmt,
    null_ls.builtins.diagnostics.eslint_d.with({
      command = paths.eslint_d_binary,
      args = {
        "--no-eslintrc",
        "--cache",
        "--resolve-plugins-relative-to",
        paths.eslint_node_modules,
        "--config",
        paths.eslint_config,
        "--stdin",
        "--format",
        "json",
        "--stdin-filename",
        "$FILENAME",
      },
    }),
    null_ls.builtins.code_actions.eslint_d,
    null_ls.builtins.formatting.eslint_d.with({
      command = paths.eslint_d_binary,
      args = {
        "--no-eslintrc",
        "--cache",
        "--resolve-plugins-relative-to",
        paths.eslint_node_modules,
        "--config",
        paths.eslint_config,
        "--stdin",
        "--stdin",
        "--fix",
        "--fix-to-stdout",
        "--stdin-filename",
        "$FILENAME",
      },
    }),
    null_ls.builtins.formatting.prettierd.with({
      env = {
        PRETTIERD_DEFAULT_CONFIG = paths.prettier_config,
      },
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
        "markdown",
        "graphql",
        "handlebars",
        "astro",
      },
    }),
    null_ls.builtins.formatting.rustywind.with({
      filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte", "html", "astro" },
    }),
    null_ls.builtins.diagnostics.cppcheck,
    null_ls.builtins.formatting.clang_format,
    null_ls.builtins.formatting.black,
    null_ls.builtins.formatting.reorder_python_imports,
    null_ls.builtins.formatting.zigfmt,
    null_ls.builtins.formatting.nimpretty,
    null_ls.builtins.formatting.crystal_format,
    null_ls.builtins.formatting.fixjson,
    null_ls.builtins.diagnostics.gitlint,
    null_ls.builtins.code_actions.gitsigns,
    null_ls.builtins.diagnostics.hadolint,
    null_ls.builtins.diagnostics.ansiblelint,
    null_ls.builtins.formatting.terraform_fmt,
    null_ls.builtins.code_actions.proselint.with({ filetypes = { "markdown" } }),
    null_ls.builtins.diagnostics.vale.with({ filetypes = { "markdown", "asciidoc" } }),
  }

  local config = {
    debug = false,
    sources = sources,
    on_attach = on_attach,
    root_dir = util.root_pattern(".root", "package.json", ".git") or lib.buffer.current.get_directory(),
  }

  null_ls.setup(config)
end

return require("lib").module.create({
  name = "language-support/null-ls",
  export = {
    setup = setup,
  },
})

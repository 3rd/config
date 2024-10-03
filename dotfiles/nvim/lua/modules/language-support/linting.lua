-- https://www.josean.com/posts/neovim-linting-and-formatting
-- https://github.com/josean-dev/dev-environment-files

return lib.module.create({
  name = "language-support/linting",
  hosts = "*",
  plugins = {
    {
      "mfussenegger/nvim-lint",
      event = "VeryLazy",
      dependencies = { "williamboman/mason.nvim" },
      config = function()
        local lint = require("lint")

        lint.linters.selene.args = {
          "--display-style",
          "json",
          "--config",
          lib.path.resolve(lib.env.dirs.vim.config, "linters/selene.toml"),
          "-",
        }
        lint.linters.oxlint = vim.tbl_extend("force", lint.linters.oxlint or {}, {
          cmd = "oxlint",
          stream = "both",
          args = {
            "--config",
            lib.path.resolve(lib.env.dirs.vim.config, "linters/oxlint.json"),
            "--format",
            "unix",
            "--jest-plugin",
            "--vitest-plugin",
            "--jsx-a11y-plugin",
            "--nextjs-plugin",
            "--react-perf-plugin",
            "--promise-plugin",
            "--node-plugin",
            "--security-plugin",
          },
        })
        -- log(table.join(lint.linters.oxlint.args))

        lint.linters_by_ft = {
          nix = { "nix", "statix" },
          cpp = { "cppcheck" },
          markdown = { "alex" },
          sh = { "shellcheck" },
          lua = vim.tbl_extend("force", {}, require("jit").arch ~= "arm64" and { "selene" } or {}),
          typescript = { "oxlint" },
          typescriptreact = { "oxlint" },
          javascript = { "oxlint" },
          javascriptreact = { "oxlint" },
        }

        local group = vim.api.nvim_create_augroup("lint", { clear = true })
        vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave", "CursorHold" }, {
          group = group,
          callback = function()
            lint.try_lint()
          end,
        })
      end,
    },
  },
})

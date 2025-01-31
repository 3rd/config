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

        -- lint.linters.eslint_d.env = {
        --   ESLINT_USE_FLAT_CONFIG = "false",
        --   ESLINT_D_ROOT = lib.path.resolve_config("linters/eslint"),
        -- }
        -- lint.linters.eslint_d.args = {
        --   "--config",
        --   lib.path.resolve_config("linters/eslint/dist/main.js"),
        --   "--no-eslintrc",
        --   "--format",
        --   "json",
        --   "--stdin",
        --   "--stdin-filename",
        --   function()
        --     return vim.api.nvim_buf_get_name(0)
        --   end,
        -- }

        lint.linters_by_ft = {
          nix = { "nix", "statix" },
          cpp = { "cppcheck" },
          markdown = { "alex" },
          sh = { "shellcheck" },
          lua = vim.tbl_extend("force", {}, require("jit").arch ~= "arm64" and { "selene" } or {}),
          -- javascript = { "eslint_d" },
          -- javascriptreact = { "eslint_d" },
          -- typescript = { "eslint_d" },
          -- typescriptreact = { "eslint_d" },
        }

        local group = vim.api.nvim_create_augroup("lint", { clear = true })
        vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
          group = group,
          callback = function()
            lint.try_lint()
          end,
        })
      end,
    },
  },
})

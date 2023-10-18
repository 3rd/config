-- https://www.josean.com/posts/neovim-linting-and-formatting
-- https://github.com/josean-dev/dev-environment-files

return lib.module.create({
  name = "language-support/linting",
  plugins = {
    {
      "mfussenegger/nvim-lint",
      event = { "BufReadPre", "BufNewFile" },
      dependencies = { "williamboman/mason.nvim" },
      config = function()
        local lint = require("lint")

        lint.linters_by_ft = {
          nix = { "nix", "statix" },
          cpp = { "cppcheck" },
          markdown = { "alex" },
          -- sh = { "shellcheck" },
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

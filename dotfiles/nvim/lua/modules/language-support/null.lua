local eslint_config_path = lib.path.resolve_config("linters/eslint/dist/main.js")

local eslint_extra_args = { "--config", eslint_config_path, "--no-eslintrc" }
local eslint_env = {
  ESLINT_USE_FLAT_CONFIG = "false",
  ESLINT_D_ROOT = lib.path.resolve_config("linters/eslint"),
}

return lib.module.create({
  name = "language-support/null",
  hosts = "*",
  plugins = {
    {
      "nvimtools/none-ls.nvim",
      event = "VeryLazy",
      dependencies = {
        "nvimtools/none-ls-extras.nvim",
      },
      config = function()
        require("null-ls").setup({
          sources = {
            require("none-ls.diagnostics.eslint_d").with({
              extra_args = eslint_extra_args,
              env = eslint_env,
            }),
            require("none-ls.code_actions.eslint_d").with({
              extra_args = eslint_extra_args,
              env = eslint_env,
            }),
            require("none-ls.formatting.eslint_d").with({
              extra_args = eslint_extra_args,
              env = eslint_env,
            }),
          },
        })
      end,
    },
  },
})

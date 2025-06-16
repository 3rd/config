local eslint_config_path = lib.path.resolve_config("linters/eslint/dist/main.js")

local global = {
  enable = true,
  extra_args = { "--config", eslint_config_path, "--no-eslintrc", "--ignore-pattern", "**/*.astro" },
  env = {
    ESLINT_USE_FLAT_CONFIG = "false",
    ESLINT_D_ROOT = lib.path.resolve_config("linters/eslint"),
  },
}

return lib.module.create({
  name = "language-support/null",
  hosts = "*",
  plugins = {
    {
      "nvimtools/none-ls.nvim",
      -- "ulisses-cruz/none-ls.nvim",
      event = "VeryLazy",
      dependencies = {
        "nvimtools/none-ls-extras.nvim",
      },
      config = function()
        local cwd = lib.path.find_root({ ".root", ".git" })
        require("null-ls").setup({
          debug = false,
          sources = {
            require("none-ls.diagnostics.eslint_d").with({
              extra_args = global.enable and global.extra_args or {},
              env = global.enable and global.env or {},
              cwd = function()
                return cwd
              end,
            }),
            require("none-ls.code_actions.eslint_d").with({
              extra_args = global.enable and global.extra_args or {},
              env = global.enable and global.env or {},
              cwd = function()
                return cwd
              end,
            }),
            require("none-ls.formatting.eslint_d").with({
              extra_args = global.enable and global.extra_args or {},
              env = global.enable and global.env or {},
              cwd = function()
                return cwd
              end,
            }),
          },
        })
      end,
    },
  },
})

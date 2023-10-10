return lib.module.create({
  -- enabled = false,
  name = "image",
  plugins = {
    {
      "3rd/image.nvim",
      dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "image.nvim"),
      -- "benlubas/image.nvim",
      -- branch = "fix_cropping_issues",
      -- event = "VeryLazy",
      ft = { "markdown", "norg", "syslang", "vimwiki" },
      opts = {},
    },
    -- {
    --   "3rd/nyancat.nvim",
    --   event = "VeryLazy",
    --   dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "nyancat.nvim"),
    --   opts = {},
    -- },
  },
})

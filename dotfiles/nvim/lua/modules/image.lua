return lib.module.create({
  name = "image",
  -- enabled = false,
  plugins = {
    {
      "3rd/image.nvim",
      -- "benlubas/image.nvim",
      -- branch = "test",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "image.nvim"),
      -- lazy = false,
      ft = { "markdown", "norg", "syslang", "vimwiki" },
      opts = {
        -- backend = "ueberzug",
        tmux_show_only_in_active_window = true,
      },
    },
    -- {
    --   "3rd/nyancat.nvim",
    --   event = "VeryLazy",
    --   dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "nyancat.nvim"),
    --   opts = {},
    -- },
  },
})

return lib.module.create({
  name = "image",
  -- enabled = false,
  hosts = { "spaceship", "macbook" },
  plugins = {
    {
      "3rd/image.nvim",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "image.nvim"),
      ft = { "markdown", "norg", "syslang", "vimwiki" },
      opts = {
        -- backend = "ueberzug",
        tmux_show_only_in_active_window = true,
      },
    },
  },
})

return lib.module.create({
  name = "image",
  -- enabled = false,
  hosts = { "spaceship", "macbook" },
  plugins = {
    {
      "3rd/image.nvim",
      dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "image.nvim"),
      ft = { "markdown", "norg", "syslang", "vimwiki" },
      opts = {
        -- backend = "ueberzug",
        tmux_show_only_in_active_window = true,
        integrations = {
          markdown = {
            only_render_image_at_cursor = true,
            only_render_image_at_cursor_mode = "popup",
          },
        },
        hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.svg" },
      },
    },
  },
})

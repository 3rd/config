return lib.module.create({
  name = "core/image",
  -- enabled = false,
  hosts = { "spaceship", "macbook" },
  plugins = {
    {
      "3rd/image.nvim",
      dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "image.nvim"),
      ft = { "markdown", "norg", "syslang", "vimwiki", "html" },
      config = function()
        require("image").setup({
          -- backend = "ueberzug",
          processor = "magick_cli",
          -- processor = "magick_rock",
          tmux_show_only_in_active_window = true,
          integrations = {
            markdown = {
              clear_in_insert_mode = false,
              only_render_image_at_cursor = false,
              only_render_image_at_cursor_mode = "popup",
            },
            html = {
              filetypes = { "html", "xhtml", "htm", "markdown" },
            },
          },
          hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.svg" },
          max_width_window_percentage = 100,
          max_height_window_percentage = false,
          window_overlap_clear_enabled = true,
        })
      end,
    },
  },
})

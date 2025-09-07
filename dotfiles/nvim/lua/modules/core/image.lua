return lib.module.create({
  name = "core/image",
  -- enabled = false,
  hosts = { "spaceship", "death" },
  plugins = {
    {
      "3rd/image.nvim",
      lazy = false,
      dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "image.nvim"),
      ft = { "markdown", "norg", "syslang", "vimwiki", "html", "org", "image_nvim" },
      config = function()
        require("image").setup({
          debug = {
            enabled = false,
            level = "debug",
            file_path = "/tmp/image.nvim.log",
            format = "compact",
          },
          -- backend = "ueberzug",
          -- backend = "sixel",
          processor = "magick_cli",
          -- processor = "magick_rock",
          tmux_show_only_in_active_window = true,
          integrations = {
            markdown = {
              enabled = true,
              clear_in_insert_mode = false,
              -- only_render_image_at_cursor = true,
              -- only_render_image_at_cursor_mode = "popup",
            },
            html = {
              filetypes = { "html", "xhtml", "htm", "markdown" },
            },
            typst = {
              enabled = false,
            },
            neorg = {
              enabled = true,
            },
            org = {
              enabled = true,
            },
          },
          hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.svg" },
          max_width_window_percentage = nil,
          max_height_window_percentage = nil,
          window_overlap_clear_enabled = true,
          window_overlap_clear_ft_ignore = {
            "cmp_menu",
            "cmp_docs",
            "snacks_notif",
            "scrollview",
            "scrollview_sign",
            "notify",
          },
        })
      end,
    },
  },
})

return lib.module.create({
  -- enabled = false,
  name = "image",
  plugins = {
    {
      "3rd/image.nvim",
      -- event = "VeryLazy",
      dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "image.nvim"),
      ft = { "markdown", "norg", "syslang" },
      opts = {
        integrations = {
          markdown = {
            enabled = true,
            sizing_strategy = "auto",
            download_remote_images = true,
            clear_in_insert_mode = false,
            only_render_image_at_cursor = false,
          },
          syslang = {
            enabled = true,
            sizing_strategy = "auto",
            download_remote_images = true,
            clear_in_insert_mode = false,
            only_render_image_at_cursor = false,
          },
        },
      },
    },
    {
      "3rd/nyancat.nvim",
      event = "VeryLazy",
      dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "nyancat.nvim"),
      opts = {},
    },
  },
})

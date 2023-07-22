return lib.module.create({
  -- enabled = false,
  name = "image",
  plugins = {
    {
      "3rd/image.nvim",
      dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "image.nvim"),
      -- event = "VeryLazy",
      ft = { "markdown", "norg" },
      opts = {},
    },
  },
})

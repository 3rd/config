return lib.module.create({
  -- enabled = false,
  name = "image",
  plugins = {
    {
      "3rd/image.nvim",
      -- event = "VeryLazy",
      dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "image.nvim"),
      ft = { "markdown", "norg" },
      opts = {},
    },
  },
})

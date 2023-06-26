return lib.module.create({
  name = "image",
  plugins = {
    {
      lazy = false,
      dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "image.nvim"),
      opts = {},
    },
  },
})

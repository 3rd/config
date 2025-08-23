return lib.module.create({
  name = "highlight-cword",
  hosts = "*",
  plugins = {
    {
      "nvimdev/cwordmini.nvim",
      event = "CursorHold",
      opts = {},
    },
  },
})

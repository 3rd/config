return lib.module.create({
  name = "vimwiki",
  enabled = false,
  plugins = {
    {
      "vimwiki/vimwiki",
      lazy = false,
    },
  },
})

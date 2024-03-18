return lib.module.create({
  name = "text-objects",
  plugins = {
    {
      "wellle/targets.vim",
      event = "VeryLazy",
    },
  },
})

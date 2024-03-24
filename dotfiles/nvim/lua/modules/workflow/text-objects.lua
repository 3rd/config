return lib.module.create({
  name = "text-objects",
  plugins = {
    {
      "wellle/targets.vim",
      event = "VeryLazy",
    },
    {
      "nvim-treesitter/nvim-treesitter-textobjects",
      event = "VeryLazy",
      dependencies = { "nvim-treesitter/nvim-treesitter" },
    },
  },
})

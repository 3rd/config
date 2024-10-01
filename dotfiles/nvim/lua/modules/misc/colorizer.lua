return lib.module.create({
  name = "misc/colorizer",
  hosts = "*",
  plugins = {
    {
      "brenoprata10/nvim-highlight-colors",
      event = "VeryLazy",
      config = function()
        require("nvim-highlight-colors").setup({
          render = "virtual",
          enable_tailwind = true,
          -- exclude_buftypes = {
          --   "prompt",
          --   "popup",
          -- },
        })
      end,
    },
  },
})

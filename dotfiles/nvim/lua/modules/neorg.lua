return lib.module.create({
  name = "neorg",
  enabled = false,
  hosts = { "spaceship", "macbook" },
  plugins = {
    {
      "nvim-neorg/neorg",
      -- build = ":Neorg sync-parsers",
      dependencies = { "nvim-lua/plenary.nvim" },
      ft = { "norg" },
      config = function()
        require("neorg").setup({
          load = {
            ["core.defaults"] = {},
            ["core.concealer"] = {},
          },
        })
      end,
    },
  },
})

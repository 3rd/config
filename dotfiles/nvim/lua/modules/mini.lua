return lib.module.create({
  name = "mini",
  hosts = "*",
  plugins = {
    {
      "echasnovski/mini.nvim",
      event = "VeryLazy",
      version = false,
      config = function()
        require("mini.ai").setup({
          {
            custom_textobjects = nil,
            mappings = {
              around = "a",
              inside = "i",
              around_next = "an",
              inside_next = "in",
              around_last = "al",
              inside_last = "il",
              goto_left = "g[",
              goto_right = "g]",
            },
            n_lines = 200,
            search_method = "cover_or_next",
            silent = false,
          },
        })
      end,
    },
  },
})

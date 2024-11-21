return lib.module.create({
  name = "mini",
  hosts = "*",
  plugins = {
    {
      "echasnovski/mini.nvim",
      event = "VeryLazy",
      version = false,
      config = function()
        local ai = require("mini.ai")
        ai.setup({
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
          n_lines = 500,
          search_method = "cover_or_next",
          silent = false,
          custom_textobjects = {
            f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
            F = ai.gen_spec.function_call(),
            c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
            o = ai.gen_spec.treesitter({
              a = { "@block.outer", "@conditional.outer", "@loop.outer" },
              i = { "@block.inner", "@conditional.inner", "@loop.inner" },
            }),
          },
        })
      end,
    },
  },
})

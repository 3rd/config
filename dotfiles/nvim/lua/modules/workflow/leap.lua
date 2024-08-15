return lib.module.create({
  name = "leap",
  hosts = "*",
  plugins = {
    {
      "ggandor/leap.nvim",
      lazy = false,
      config = function()
        local leap = require("leap")
        leap.opts.labels = "sfnjklhodweimbuyvrgtaqpcxz"
        leap.opts.safe_labels = "sfnut"

        vim.keymap.set({ "n", "x", "o" }, "r", "<Plug>(leap)")
        vim.keymap.set({ "n", "x", "o" }, "R", "<Plug>(leap-backward)")
      end,
    },
  },
})

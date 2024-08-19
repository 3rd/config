return lib.module.create({
  name = "spider",
  hosts = "*",
  plugins = {
    {
      "chrisgrieser/nvim-spider",
      event = "VeryLazy",
      config = function()
        vim.keymap.set({ "n", "x" }, "w", "<cmd>lua require('spider').motion('w')<CR>", { desc = "Spider-w" })
        vim.keymap.set({ "n", "x" }, "e", "<cmd>lua require('spider').motion('e')<CR>", { desc = "Spider-e" })
        vim.keymap.set({ "n", "x" }, "b", "<cmd>lua require('spider').motion('b')<CR>", { desc = "Spider-b" })
      end,
    },
  },
})

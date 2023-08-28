local setup = function()
  require("refactoring").setup()

  vim.keymap.set(
    { "n", "v" },
    "<leader>ar",
    ":lua require('refactoring').select_refactor()<CR>",
    { noremap = true, silent = true, expr = false, desc = "Refactor" }
  )
end

return lib.module.create({
  name = "language-support/refactoring",
  plugins = {
    {
      "ThePrimeagen/refactoring.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
      },
      config = setup,
    },
  },
})

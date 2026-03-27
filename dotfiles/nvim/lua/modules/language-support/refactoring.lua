local setup = function()
  local refactoring = require("refactoring")

  refactoring.setup({
    print_var_statements = {
      typescript = {
        "console.log('🐞 %s', %s)",
      },
      javascript = {
        "console.log('🐞 %s', %s)",
      },
    },
  })

  -- vim.keymap.set(
  --   { "n", "v" },
  --   "<leader>ar",
  --   ":lua require('refactoring').select_refactor()<cr>",
  --   { noremap = true, silent = true, expr = false, desc = "Refactor" }
  -- )
  -- vim.keymap.set(
  --   { "n", "v" },
  --   "<leader>ef",
  --   ":Refactor extract ",
  --   { noremap = true, silent = true, expr = false, desc = "Extract function" }
  -- )
  -- vim.keymap.set(
  --   { "n", "v" },
  --   "<leader>ev",
  --   ":Refactor extract_var ",
  --   { noremap = true, silent = true, expr = false, desc = "Extract variable" }
  -- )

  vim.keymap.set({ "n", "v" }, "<leader>if", function()
    refactoring.refactor("Inline Function")
  end, { noremap = true, silent = true, expr = false, desc = "Inline function" })
  vim.keymap.set(
    { "n", "v" },
    "<leader>iv",
    ":Refactor inline_var",
    { noremap = true, silent = true, expr = false, desc = "Inline function" }
  )

  vim.keymap.set(
    { "n", "v" },
    "<leader>p",
    ":lua require('refactoring').debug.print_var()<cr>",
    { noremap = true, silent = true, expr = false, desc = "Print var" }
  )
  vim.keymap.set(
    { "n", "v" },
    "<leader>P",
    ":lua require('refactoring').debug.cleanup({})<cr>",
    { noremap = true, silent = true, expr = false, desc = "Clear var prints" }
  )
end

return lib.module.create({
  name = "language-support/refactoring",
  hosts = "*",
  plugins = {
    {
      "ThePrimeagen/refactoring.nvim",
      event = "VeryLazy",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
      },
      config = setup,
    },
  },
})

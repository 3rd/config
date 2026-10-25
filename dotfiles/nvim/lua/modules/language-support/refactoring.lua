local format_print_var = function(opts)
  return string.format("console.log('🐞 %s', %s)", opts.identifier:gsub("'", "\\'"), opts.identifier)
end

local setup = function()
  local refactoring = require("refactoring")
  local debug = require("refactoring.debug")

  refactoring.setup({
    debug = {
      print_var = {
        code_generation = {
          print_var = {
            javascript = format_print_var,
            typescript = format_print_var,
            tsx = format_print_var,
          },
        },
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

  vim.keymap.set(
    { "n", "x" },
    "<leader>iv",
    refactoring.inline_var,
    { noremap = true, silent = true, expr = true, desc = "Inline variable" }
  )

  vim.keymap.set("n", "<leader>p", function()
    return debug.print_var() .. "iw"
  end, { noremap = true, silent = true, expr = true, desc = "Print var" })
  vim.keymap.set("x", "<leader>p", debug.print_var, { noremap = true, silent = true, expr = true, desc = "Print var" })
  vim.keymap.set("n", "<leader>P", function()
    return "gg" .. debug.cleanup() .. "G"
  end, { noremap = true, silent = true, expr = true, desc = "Clear var prints" })
  vim.keymap.set(
    "x",
    "<leader>P",
    debug.cleanup,
    { noremap = true, silent = true, expr = true, desc = "Clear var prints" }
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

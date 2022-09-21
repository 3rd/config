local setup = function()
  -- https://github.com/ThePrimeagen/refactoring.nvim
  require("refactoring").setup({})
end

return require("lib").module.create({
  name = "workflow/refactoring",
  plugins = {
    "ThePrimeagen/refactoring.nvim",
    requires = {
      { "nvim-lua/plenary.nvim" },
      { "nvim-treesitter/nvim-treesitter" },
    },
    config = setup,
  },
  mappings = {
    { "v", "<leader>ef", [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Function')<CR>]] },
    { "v", "<leader>ev", [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Variable')<CR>]] },
    { "n", "<leader>ei", [[ <Cmd>lua require('refactoring').refactor('Inline Variable')<CR>]] },
    { "v", "<leader>ei", [[ <Esc><Cmd>lua require('refactoring').refactor('Inline Variable')<CR>]] },
    { "n", "<leader>eb", [[ <Cmd>lua require('refactoring').refactor('Extract Block')<CR>]] },
    { "n", "<leader>ee", ":lua require('refactoring').select_refactor()<CR>" },
    { "v", "<leader>ee", ":lua require('refactoring').select_refactor()<CR>" },
    -- { "v", "<leader>eff", [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Function To File')<CR>]] },
    -- { "n", "<leader>ebf", [[ <Cmd>lua require('refactoring').refactor('Extract Block To File')<CR>]] },
  },
})

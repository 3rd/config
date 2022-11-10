local setup = {
  focus = function()
    require("focus").setup({
      enable = true,
      signcolumn = false,
      cursorline = false,
    })
    vim.cmd("FocusDisable")
  end,
  maximize = function()
    require("maximize").setup({
      default_keymaps = false,
    })
  end,
  peepsight = function()
    require("peepsight").setup({
      -- lua
      "function_definition",
      -- go
      "function_declaration",
      "method_declaration",
      "func_literal",
      -- typescript
      "arrow_function",
      "function_declaration",
      "generator_function_declaration",
      "method_definition",
    })
  end,
}

return require("lib").module.create({
  name = "ui/focus",
  plugins = {
    { "beauwilliams/focus.nvim", config = setup.focus, module = "focus" },
    { "declancm/maximize.nvim", config = setup.maximize },
    {
      "koenverburg/peepsight.nvim",
      -- "3rd/peepsight.nvim",
      -- branch = "patch-1",
      after = "nvim-treesitter",
      config = setup.peepsight,
    },
  },
  mappings = {
    -- focus
    { "n", "<c-left>", ":lua require'focus'.split_command('h')<CR>" },
    { "n", "<c-down>", ":lua require'focus'.split_command('j')<CR>" },
    { "n", "<c-up>", ":lua require'focus'.split_command('k')<CR>" },
    { "n", "<c-right>", ":lua require'focus'.split_command('l')<CR>" },
    -- maximize
    { "n", "<leader>f", "<Cmd>lua require('maximize').toggle()<CR>" },
  },
  actions = {
    { "n", "Peepsight: Toggle context focusing", "Peepsight" },
  },
})

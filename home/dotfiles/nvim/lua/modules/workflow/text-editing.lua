local setup_surround = function()
  require("nvim-surround").setup({
    keymaps = {
      insert = "<C-g>s",
      insert_line = "<C-g>S",
      normal = "ys",
      normal_cur = "yss",
      normal_line = "yS",
      normal_cur_line = "ySS",
      visual = "S",
      visual_line = "gS",
      delete = "ds",
      change = "cs",
    },
  })
end

return lib.module.create({
  name = "workflow/text-editing",
  plugins = {
    {
      "christoomey/vim-sort-motion",
      event = "VeryLazy",
    },
    {
      "tommcdo/vim-lion",
      event = "VeryLazy",
    },
    {
      "kylechui/nvim-surround",
      event = "VeryLazy",
      config = setup_surround,
    },
    {
      "johmsalas/text-case.nvim", -- :Subs
      event = "VeryLazy",
    },
  },
})

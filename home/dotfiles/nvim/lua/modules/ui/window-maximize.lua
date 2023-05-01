local setup_maximize = function()
  require("maximize").setup({
    default_keymaps = false,
  })
end

return lib.module.create({
  name = "ui/window-maximize",
  plugins = {
    {
      "declancm/maximize.nvim",
      config = setup_maximize,
    },
  },
  mappings = {
    { "n", "<leader>f", "<Cmd>lua require('maximize').toggle()<CR>", "Toggle maximize" },
  },
})

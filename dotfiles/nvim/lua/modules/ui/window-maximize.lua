return lib.module.create({
  name = "ui/window-maximize",
  hosts = "*",
  plugins = {
    {
      "declancm/maximize.nvim",
      opts = {
        default_keymaps = false,
      },
    },
  },
  mappings = {
    { "n", "<leader>f", "<Cmd>lua require('maximize').toggle()<CR>", "Toggle maximize" },
  },
})

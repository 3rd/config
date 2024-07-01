return lib.module.create({
  name = "undotree",
  hosts = "*",
  plugins = {
    {
      "mbbill/undotree",
      keys = {
        { "<leader>u", ":UndotreeToggle<CR>:UndotreeFocus<cr>", desc = "Undo tree" },
      },
    },
  },
})

return lib.module.create({
  name = "undotree",
  hosts = "*",
  plugins = {
    {
      "mbbill/undotree",
      keys = {
        { "U", ":UndotreeToggle<CR>:UndotreeFocus<cr>", desc = "Undo tree" },
      },
    },
  },
})

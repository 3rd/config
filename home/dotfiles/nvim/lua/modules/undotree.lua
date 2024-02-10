return lib.module.create({
  name = "undotree",
  plugins = {
    {
      "mbbill/undotree",
      keys = {
        { "U", ":UndotreeToggle<CR>:UndotreeFocus<cr>", desc = "Undo tree" },
      },
    },
  },
})

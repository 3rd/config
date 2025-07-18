vim.g.undotree_RelativeTimestamp = 0
return lib.module.create({
  name = "workflow/undotree",
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

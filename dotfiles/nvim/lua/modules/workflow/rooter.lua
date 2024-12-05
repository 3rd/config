local setup = function()
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("rooter", {}),
    callback = function()
      local root = lib.path.find_root()
      if not root then return end
      local root_path = vim.fs.dirname(root) .. "/"
      vim.fn.chdir(root_path)
    end,
  })
end

return lib.module.create({
  name = "workflow/rooter",
  hosts = "*",
  setup = setup,
})

local setup = function()
  local group = vim.api.nvim_create_augroup("rooter", {})
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function()
      if vim.g.rooter_done then return end
      local target = lib.path.find_root()
      if not target then return end
      vim.g.rooter_done = true
      pcall(vim.api.nvim_clear_autocmds, { group = group })
      vim.fn.chdir(target)
    end,
  })
end

return lib.module.create({
  name = "workflow/rooter",
  hosts = "*",
  setup = setup,
})

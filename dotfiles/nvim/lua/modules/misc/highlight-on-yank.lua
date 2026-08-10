local setup = function()
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("highlight-on-yank", {}),
    pattern = "*",
    callback = function()
      vim.hl.hl_op()
    end,
  })
end

return lib.module.create({
  name = "misc/highlight-on-yank",
  hosts = "*",
  setup = setup,
})

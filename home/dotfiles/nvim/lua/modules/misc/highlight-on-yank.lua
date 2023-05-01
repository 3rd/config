local setup = function()
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("highlight-on-yank", {}),
    pattern = "*",
    callback = function()
      vim.highlight.on_yank()
    end,
  })
end

return lib.module.create({
  name = "misc/highlight-on-yank",
  setup = setup,
})

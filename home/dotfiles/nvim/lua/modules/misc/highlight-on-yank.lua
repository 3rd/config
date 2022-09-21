local setup = function()
  vim.api.nvim_create_autocmd("TextYankPost", {
    pattern = "*",
    callback = function()
      vim.highlight.on_yank()
    end,
  })
end

return require("lib").module.create({
  name = "misc/highlight-on-yank",
  setup = setup,
})

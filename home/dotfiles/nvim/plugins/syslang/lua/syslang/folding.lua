local setup = function()
  local group = vim.api.nvim_create_augroup("syslang:folds", { clear = true })
  local bufnr = vim.api.nvim_get_current_buf()

  vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      vim.cmd("silent! loadview")
    end,
  })
  vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      vim.cmd("silent! mkview")
    end,
  })
end

return {
  setup = setup,
}

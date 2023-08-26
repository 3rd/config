local setup = function()
  vim.opt.foldmethod = "expr"
  vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  vim.cmd("silent! loadview")

  local group = vim.api.nvim_create_augroup("SyslangFoldPersistence", { clear = true })
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

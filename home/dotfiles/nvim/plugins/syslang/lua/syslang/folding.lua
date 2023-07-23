local handlers = {
  enter = function()
    vim.cmd("silent! loadview")
  end,
  leave = function()
    vim.cmd("mkview")
  end,
  -- write_pre = function()
  --   vim.cmd("mkview")
  -- end,
}

local register = function()
  vim.opt.foldmethod = "expr"
  vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"

  local group = vim.api.nvim_create_augroup("SyslangFoldPersistence", { clear = true })
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
    group = group,
    buffer = bufnr,
    callback = handlers.enter,
  })
  vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
    group = group,
    buffer = bufnr,
    callback = handlers.leave,
  })
  -- vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  --   group = group,
  --   buffer = bufnr,
  --   callback = handlers.write_pre,
  -- })
end

return {
  register = register,
  handlers = handlers,
}

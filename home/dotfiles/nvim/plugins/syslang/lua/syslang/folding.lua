local lib = require("lib")

local handlers = {
  enter = function()
    vim.cmd("silent! loadview")
  end,
  leave = function()
    vim.cmd("mkview")
  end,
  write_pre = function()
    vim.cmd("mkview")
  end,
}

local register = function()
  vim.opt.foldmethod = "expr"
  vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
  -- vim.cmd("silent! loadview")

  local group =
    vim.api.nvim_create_augroup("SyslangFoldPersitence", { clear = true })
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
end

return {
  register = register,
  handlers = handlers,
}

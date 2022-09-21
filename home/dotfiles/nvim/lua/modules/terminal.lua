local setup = function()
  vim.api.nvim_create_autocmd("TermOpen", {
    pattern = "*",
    callback = function()
      vim.opt.number = false
      vim.opt.relativenumber = false
      vim.cmd("startinsert")
    end,
  })
end

return require("lib").module.create({
  name = "terminal",
  setup = setup,
})

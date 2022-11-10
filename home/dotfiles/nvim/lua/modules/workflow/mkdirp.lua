local setup = function()
  vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    pattern = "*",
    group = vim.api.nvim_create_augroup("auto_create_dir", { clear = true }),
    callback = function(ctx)
      local dir = vim.fn.fnamemodify(ctx.file, ":p:h")
      vim.fn.mkdir(dir, "p")
    end,
  })
end

return require("lib").module.create({
  name = "workflow/mkdirp",
  setup = setup,
})

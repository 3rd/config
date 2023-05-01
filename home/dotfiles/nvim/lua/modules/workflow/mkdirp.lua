local setup = function()
  vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = vim.api.nvim_create_augroup("mkdirp", {}),
    pattern = "*",
    callback = function(ctx)
      local dir = vim.fn.fnamemodify(ctx.file, ":p:h")
      vim.fn.mkdir(dir, "p")
    end,
  })
end

return lib.module.create({
  name = "workflow/mkdirp",
  setup = setup,
})

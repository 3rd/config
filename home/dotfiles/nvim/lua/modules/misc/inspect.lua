local inspect = function()
  for _, i1 in ipairs(vim.fn.synstack(vim.fn.line("."), vim.fn.col("."))) do
    local i2 = vim.fn.synIDtrans(i1)
    local n1 = vim.fn.synIDattr(i1, "name")
    local n2 = vim.fn.synIDattr(i2, "name")
    print(n1, "->", n2)
  end
  vim.api.nvim_exec2("Inspect", {})
end

return lib.module.create({
  name = "misc/inspect",
  mappings = {
    { "n", "<F10>", inspect },
  },
})

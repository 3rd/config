local inspect_at_cursor = function()
  for _, i1 in ipairs(vim.fn.synstack(vim.fn.line("."), vim.fn.col("."))) do
    local i2 = vim.fn.synIDtrans(i1)
    local n1 = vim.fn.synIDattr(i1, "name")
    local n2 = vim.fn.synIDattr(i2, "name")
    print(n1, "->", n2)
  end
end

return require("lib").module.create({
  name = "dev/syntax-inspector",
  mappings = {
    {
      "n",
      "<F10>",
      ":lua require('modules/dev/syntax-inspector').export.inspect_at_cursor()<cr>",
    },
  },
  export = {
    inspect_at_cursor = inspect_at_cursor,
  },
})

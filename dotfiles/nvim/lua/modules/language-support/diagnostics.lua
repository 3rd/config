local setup = function()
  -- vim.diagnostic
  vim.diagnostic.config({
    float = { source = true },
    severity_sort = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    virtual_text = { prefix = "»", spacing = 4 },
  })

  -- signs
  local signs = { Error = " ", Warn = " ", Info = " ", Hint = " 󰌶" }
  for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
  end
end

return lib.module.create({
  name = "language-support/diagnostics",
  hosts = "*",
  setup = setup,
})

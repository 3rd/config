local setup = function()
  local config = {
    diagnostic = {
      float = { source = "always" },
      severity_sort = true,
      signs = true,
      underline = true,
      update_in_insert = false,
      virtual_text = { prefix = "»", spacing = 4 },
    },
    signs = { Error = " ", Warn = " ", Info = " ", Hint = " " },
  }

  vim.diagnostic.config(config.diagnostic)

  for type, icon in pairs(config.signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
  end
end

return require("lib").module.create({
  name = "language-support/diagnostic",
  setup = setup,
})

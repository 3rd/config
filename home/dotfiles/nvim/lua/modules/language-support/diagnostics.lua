-- builtin
vim.diagnostic.config({
  float = { source = "always" },
  severity_sort = true,
  signs = true,
  underline = false,
  update_in_insert = false,
  virtual_text = { prefix = "»", spacing = 4 },
  -- virtual_lines = { highighlight_whole_line = false },
})

-- signs
local signs = { Error = " ", Warn = " ", Info = " ", Hint = " 󰌶" }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

return lib.module.create({
  name = "language-support/diagnostics",
  plugins = {
    -- {
    --   "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
    --   event = { "BufReadPost", "BufAdd", "BufNewFile" },
    --   opts = {},
    -- },
  },
})

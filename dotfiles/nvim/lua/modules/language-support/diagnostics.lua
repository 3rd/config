local virtual_text_config = { prefix = "»", spacing = 4 }

local setup = function()
  -- vim.diagnostic
  vim.diagnostic.config({
    float = { source = true },
    severity_sort = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    virtual_text = virtual_text_config,
    virtual_lines = false,
    jump = { float = true },
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
  mappings = {
    {
      "n",
      "<leader>td",
      function()
        vim.diagnostic.config({
          virtual_text = vim.diagnostic.config().virtual_text == false and virtual_text_config or false,
          virtual_lines = not vim.diagnostic.config().virtual_lines,
        })
      end,
      "Toggle diagnostics virtual_lines",
    },
  },
})

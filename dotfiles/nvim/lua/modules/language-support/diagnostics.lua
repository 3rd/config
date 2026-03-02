local virtual_text_config = { prefix = "»", spacing = 4 }
local diagnostic_signs_text = {
  [vim.diagnostic.severity.ERROR] = " ",
  [vim.diagnostic.severity.WARN] = " ",
  [vim.diagnostic.severity.INFO] = " ",
  [vim.diagnostic.severity.HINT] = " 󰌶",
}
local diagnostic_signs_numhl = {
  [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
  [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
  [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
  [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
}

local setup = function()
  vim.diagnostic.config({
    float = { source = true },
    severity_sort = true,
    signs = {
      text = diagnostic_signs_text,
      numhl = diagnostic_signs_numhl,
    },
    underline = true,
    update_in_insert = false,
    virtual_text = virtual_text_config,
    virtual_lines = false,
    jump = {
      on_jump = function(diagnostic, bufnr)
        if not diagnostic then return end
        vim.diagnostic.open_float({
          bufnr = bufnr,
          scope = "cursor",
          source = true,
        })
      end,
    },
  })
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

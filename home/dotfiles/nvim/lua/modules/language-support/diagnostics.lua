local config = {
  diagnostic = {
    float = { source = "always" },
    severity_sort = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    virtual_text = { prefix = "»", spacing = 4 },
  },
  signs = { Error = " ", Warn = " ", Info = " ", Hint = "" },
}

local setup = function()
  vim.diagnostic.config(config.diagnostic)

  for type, icon in pairs(config.signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
  end
end

local setup_trouble = function()
  require("trouble").setup({
    position = "bottom",
    height = 10,
    width = 50,
    icons = true,
    mode = "workspace_diagnostics", -- "workspace_diagnostics", "document_diagnostics", "quickfix", "lsp_references", "loclist"
    fold_open = "",
    fold_closed = "",
    group = true,
    padding = true,
    action_keys = {
      close = "q", -- close the list
      cancel = "<esc>", -- cancel the preview and get back to your last window / buffer / cursor
      refresh = "r", -- manually refresh
      jump = { "<cr>", "<tab>" }, -- jump to the diagnostic or open / close folds
      open_split = { "<c-s>" }, -- open buffer in new split
      open_vsplit = { "<c-v>" }, -- open buffer in new vsplit
      open_tab = { "<c-t>" }, -- open buffer in new tab
      jump_close = { "o" }, -- jump to the diagnostic and close the list
      toggle_mode = "m", -- toggle between "workspace" and "document" diagnostics mode
      toggle_preview = "P", -- toggle auto_preview
      hover = "K", -- opens a small popup with the full multiline message
      preview = "p", -- preview the diagnostic location
      close_folds = { "zM", "zm" }, -- close all folds
      open_folds = { "zR", "zr" }, -- open all folds
      toggle_fold = { "<tab", "zA", "za" }, -- toggle fold of current file
      previous = "k", -- previous item
      next = "j", -- next item
    },
    indent_lines = true, -- add an indent guide below the fold icons
    auto_open = false, -- automatically open the list when you have diagnostics
    auto_close = false, -- automatically close the list when you have no diagnostics
    auto_preview = true, -- automatically preview the location of the diagnostic. <esc> to close preview and go back to last window
    auto_fold = false, -- automatically fold a file trouble list at creation
    auto_jump = { "lsp_definitions" }, -- for the given modes, automatically jump if there is only a single result
    use_diagnostic_signs = true,
  })
end

return lib.module.create({
  name = "language-support/diagnostics",
  setup = setup,
  plugins = {
    {
      "folke/trouble.nvim",
      cmd = { "Trouble", "TroubleToggle" },
      config = setup_trouble,
    },
  },
  mappings = {
    { "n", "<leader>t", "<cmd>TroubleToggle<cr>" },
  },
})

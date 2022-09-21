local setup = function()
  local group = vim.api.nvim_create_augroup("ui/auto-resize", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    desc = "Auto-resize panes on window resize.",
    command = "tabdo wincmd =",
    group = group,
  })
  vim.cmd("autocmd VimEnter * doautocmd FileType")
end

return require("lib").module.create({
  name = "ui/auto-resize",
  setup = setup,
})

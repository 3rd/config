local setup = function()
  vim.g.markdown_fenced_languages = {
    "ts=typescript",
    "tsx=typescriptreact",
    "js=javascript",
    "jsx=javascriptreact",
  }
end

return lib.module.create({
  name = "language-support/markdown",
  setup = setup,
})

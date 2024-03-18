local setup = function()
  vim.g.markdown_fenced_languages = {
    "ts=typescript",
    "tsx=typescriptreact",
    "js=javascript",
    "jsx=javascriptreact",
  }
end

local setup_markdown_preview = function()
  vim.g.mkdp_filetypes = { "markdown" }
  vim.g.mkdp_echo_preview_url = 1
  -- vim.g.mkdp_browser = "$BROWSER"
end

return lib.module.create({
  name = "language-support/languages/markdown",
  setup = setup,
  plugins = {
    {
      "iamcco/markdown-preview.nvim",
      enabled = false,
      build = "cd app && npm install",
      ft = "markdown",
      config = setup_markdown_preview,
    },
  },
})

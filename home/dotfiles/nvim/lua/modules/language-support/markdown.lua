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
  vim.g.mkdp_browser = "google-chrome-stable"
  vim.g.mkdp_echo_preview_url = 1
end

return lib.module.create({
  name = "language-support/markdown",
  setup = setup,
  plugins = {
    {
      "iamcco/markdown-preview.nvim",
      build = "cd app && npm install",
      ft = "markdown",
      config = setup_markdown_preview,
    },
  },
})

local lib = require("lib")

local setup = function()
  vim.g.markdown_fenced_languages = {
    "ts=typescript",
  }
end

return lib.module.create({
  name = "language-support/markdown",
  setup = setup,
  plugins = {
    {
      "iamcco/markdown-preview.nvim",
      run = "cd app && npm install",
      setup = function()
        vim.g.mkdp_filetypes = { "markdown" }
        vim.g.mkdp_auto_start = 1
      end,
      ft = { "markdown" },
    },
  },
})

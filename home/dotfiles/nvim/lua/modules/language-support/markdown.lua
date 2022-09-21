local lib = require("lib")

local setup = function()
  vim.g.markdown_fenced_languages = {
    "ts=typescript",
  }
end

return lib.module.create({
  name = "language-support/markdown",
  setup = setup,
})

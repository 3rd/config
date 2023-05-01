local setup_template_string = function()
  require("template-string").setup()
end

return lib.module.create({
  name = "language-support/typescript",
  plugins = {
    {
      "axelvc/template-string.nvim",
      ft = {
        "typescript",
        "typescriptreact",
        "javascript",
        "javascriptreact",
      },
      config = setup_template_string,
    },
  },
})

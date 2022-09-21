local setup = function()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "make", "snippets" },
    callback = function()
      vim.bo.expandtab = false
    end,
  })

  vim.filetype.add({
    extension = {
      astro = "astro",
      mdx = "markdown",
    },
  })
end

return require("lib").module.create({
  name = "filetype",
  setup = setup,
})

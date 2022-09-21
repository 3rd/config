local setup = function()
  local indent_blankline = require("indent_blankline")

  indent_blankline.setup({
    space_char_blankline = " ",
    use_treesitter = true,
    show_end_of_line = true,
    show_trailing_blankline_indent = false,
    show_first_indent_level = false,
    filetype_exclude = { "", "help", "packer", "lspinfo", "lsp-installer", "null-ls-info", "NvimTree" },
  })
end

return require("lib").module.create({
  name = "indent-guides",
  plugins = {
    { "lukas-reineke/indent-blankline.nvim", config = setup },
  },
})

local setup = function()
  local indent_blankline = require("indent_blankline")

  indent_blankline.setup({
    -- char = "¦",
    space_char_blankline = " ",
    use_treesitter = true,
    show_end_of_line = false,
    show_trailing_blankline_indent = false,
    -- show_first_indent_level = false,
    show_foldtext = false,
    char_priority = 50,
    char_highlight_list = {
      "IndentBlanklineIndent1",
      "IndentBlanklineIndent2",
      "IndentBlanklineIndent3",
      "IndentBlanklineIndent4",
      "IndentBlanklineIndent5",
      "IndentBlanklineIndent6",
    },
    filetype_exclude = {
      "",
      "help",
      "packer",
      "lspinfo",
      "lsp-installer",
      "null-ls-info",
      "NvimTree",
      -- "syslang",
    },
  })

  vim.cmd("IndentBlanklineRefresh")
end

return lib.module.create({
  enabled = true,
  name = "indent-guides",
  plugins = {
    {
      "lukas-reineke/indent-blankline.nvim",
      event = "VeryLazy",
      config = setup,
    },
    -- { "shellRaining/hlchunk.nvim" } -- alternative
  },
})

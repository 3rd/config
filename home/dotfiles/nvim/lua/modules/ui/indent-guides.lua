local setup = function()
  -- local indent_blankline = require("ibl")
  --
  -- indent_blankline.setup({
  --   -- char = "¦",
  --   space_char_blankline = " ",
  --   use_treesitter = true,
  --   show_end_of_line = false,
  --   show_trailing_blankline_indent = false,
  --   -- show_first_indent_level = false,
  --   show_foldtext = false,
  --   char_priority = 50,
  --   char_highlight_list = {
  --     "IndentBlanklineIndent1",
  --     "IndentBlanklineIndent2",
  --     "IndentBlanklineIndent3",
  --     "IndentBlanklineIndent4",
  --     "IndentBlanklineIndent5",
  --     "IndentBlanklineIndent6",
  --   },
  --   filetype_exclude = {
  --     "",
  --     "help",
  --     "NvimTree",
  --     "lsp-installer",
  --     "lspinfo",
  --     "null-ls-info",
  --     "packer",
  --   },
  -- })

  local highlight = {
    "IndentBlanklineIndent1",
    "IndentBlanklineIndent2",
    "IndentBlanklineIndent3",
    "IndentBlanklineIndent4",
    "IndentBlanklineIndent5",
    "IndentBlanklineIndent6",
  }

  require("ibl").setup({
    indent = {
      char = "│",
      highlight = highlight,
      priority = 12, -- ufo
      smart_indent_cap = true,
      tab_char = nil,
    },
    scope = { enabled = false },
  })

  require("ibl").refresh()
end

return lib.module.create({
  name = "indent-guides",
  -- enabled = false,
  plugins = {
    {
      "lukas-reineke/indent-blankline.nvim",
      event = "VeryLazy",
      config = setup,
    },
  },
})

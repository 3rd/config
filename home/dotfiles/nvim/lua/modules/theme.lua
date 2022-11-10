-- Resources:
-- https://machineroom.purplekraken.com/posts/neovim-theme-lua/
-- https://www.locatelli.dev/nv-ide/
-- https://github.com/norcalli/nvim-base16.lua/blob/master/lua/base16.lua#L102

local setup = function()
  local catppuccin = require("catppuccin")
  local colors = require("catppuccin.palettes").get_palette()

  catppuccin.setup({
    transparent_background = false,
    term_colors = false,
    color_overrides = {
      all = {
        base = "#191923", -- background
        text = "#BDC7EE", -- foreground
        mantle = "#21222c", -- sidebar
        crust = "#464A6C", -- VertSplit
        subtext1 = "#B8C0E0",
        subtext0 = "#A5ADCB",
        overlay0 = "#7479a5", -- PmenuThumb:bg, NonText, WildMenu
        overlay1 = "#9296b9", -- Conceal
        overlay2 = "#9296b9", -- Pmenu:fg
        surface0 = "#343751", -- CursorLine:bg, Pmenu:bg
        surface1 = "#444869", -- SignColumn:fg, Substitute:bg, LineNr:fg, PmenuSel:bg, PmenuSbar:bg, Visual:bg, Whitespace:bg
        surface2 = "#7378a5", -- Comment
        blue = "#66ADFF", -- FloatBorder, Function, Type
        flamingo = "#DC5FFB", -- @symbol, code block
        green = "#ABD279", -- String, DiffAdd
        lavender = "#fba03c", -- CursorLineNr
        maroon = "#EE99A0",
        mauve = "#B980FF", -- conditionals, loops, keywords,
        peach = "#FB945F", -- MatchParen, Constant, Number
        pink = "#e91e63", -- Keyword, PreProc, Include
        red = "#ec8179", -- Conditional, DiffDel
        rosewater = "#ffdddd",
        sapphire = "#7DC4E4", -- struct
        sky = "#9297B9", -- IncSearch, Operator
        teal = "#17cfbc", -- Character, field
        yellow = "#ffc505", -- Structure
      },
    },
    styles = {
      comments = { "italic" },
      conditionals = { "italic" },
      loops = {},
      functions = {},
      keywords = {},
      strings = {},
      variables = {},
      numbers = {},
      booleans = {},
      properties = {},
      types = {},
      operators = {},
    },
    integrations = {
      cmp = true,
      gitsigns = true,
      indent_blankline = { enabled = true, colored_indent_levels = false },
      markdown = true,
      native_lsp = {
        enabled = true,
        virtual_text = {
          errors = { "italic" },
          hints = { "italic" },
          warnings = { "italic" },
          information = { "italic" },
        },
        underlines = {
          errors = { "underline" },
          hints = { "underline" },
          warnings = { "underline" },
          information = { "underline" },
        },
      },
      notify = true,
      nvimtree = { enabled = true, show_root = false, transparent_panel = false },
      treesitter = true,
    },
    custom_highlights = {
      -- VertSplit = { fg = "#525A7A" },
      -- NormalFloat = { bg = "#343751" },
      ["@slang.document.title"] = { fg = "#fba03c", style = { "bold" } },
      ["@slang.document.meta"] = { fg = "#fba03c" },
      ["@slang.document.meta.field"] = { fg = "#d2ced4" },
      ["@slang.document.meta.field.key"] = { fg = "#e3b959" },
      ["@slang.error"] = { bg = "#ff0000", fg = "#ffffff" },
      ["@slang.bold"] = { style = { "bold" } },
      ["@slang.italic"] = { style = { "italic" } },
      ["@slang.underline"] = { style = { "underline" } },
      ["@slang.comment"] = { fg = "#7378a5" },
      ["@slang.string"] = { fg = "#4efa8e" },
      ["@slang.number"] = { fg = "#71c9f6" },
      ["@slang.ticket"] = { fg = "#fa89f6" },
      ["@slang.time"] = { fg = "#FC824A" },
      ["@slang.timerange"] = { fg = "#FC824A" },
      ["@slang.date"] = { fg = "#FC824A" },
      ["@slang.daterange"] = { fg = "#FC824A" },
      ["@slang.datetime"] = { fg = "#FC824A" },
      ["@slang.datetimerange"] = { fg = "#FC824A" },
      ["@slang.heading_1.text"] = { fg = "#9999FF", style = { "bold" } },
      ["@slang.heading_1.marker"] = { fg = "#9999FF" },
      ["@slang.heading_2.text"] = { fg = "#C08FFF", style = { "bold" } },
      ["@slang.heading_2.marker"] = { fg = "#C08FFF" },
      ["@slang.heading_3.text"] = { fg = "#E38FFF", style = { "bold" } },
      ["@slang.heading_3.marker"] = { fg = "#E38FFF" },
      ["@slang.heading_4.text"] = { fg = "#FFC78F", style = { "bold" } },
      ["@slang.heading_4.marker"] = { fg = "#FFC78F" },
      ["@slang.heading_5.text"] = { fg = "#f0969f", style = { "bold" } },
      ["@slang.heading_5.marker"] = { fg = "#f0969f" },
      ["@slang.heading_6.text"] = { fg = "#04D3D0", style = { "bold" } },
      ["@slang.heading_6.marker"] = { fg = "#04D3D0" },
      ["@slang.section"] = { fg = "#7bdbc2" },
      ["@slang.pipe"] = { fg = "#abc9c2" },
      ["@slang.task_normal"] = { fg = "#BDC7EE" },
      ["@slang.task_active"] = { fg = "#57CC99" },
      ["@slang.task_done"] = { fg = "#7378a5" },
      ["@slang.task_blocked"] = { fg = "#fa4040" },
      ["@slang.task_session"] = { fg = "#7378a5" },
      ["@slang.task_schedule"] = { fg = "#FF8000" },
      ["@slang.tag.hash"] = { fg = "#5BC0EB" },
      ["@slang.tag.positive"] = { fg = "#9BC53D" },
      ["@slang.tag.negative"] = { fg = "#FA4224" },
      ["@slang.tag.context"] = { fg = "#FDDC5C" },
      ["@slang.tag.danger"] = { bg = "#C3423F", fg = "#ffffff" },
      ["@slang.tag.identifier"] = { fg = "#e38fff" },
      ["@slang.link_plain"] = { fg = "#5BC0CD", style = { "italic" } },
      ["@slang.link"] = { fg = "#5BC0CD", style = { "italic" } },
      -- ["@slang.code_block"] = { bg = "#202020" },
      ["@slang.inline_code"] = { fg = "#ff824a" },
      ["@slang.code_block_start"] = { fg = "#7378a5", style = { "italic" } },
      ["@slang.code_block_language"] = { fg = "#6F75A9", style = { "italic" } },
      ["@slang.code_block_content"] = { fg = "#BDC7EE" },
      ["@slang.code_block_end"] = { fg = "#7378a5", style = { "italic" } },
    },
  })

  -- latte, frappe, macchiato, mocha
  vim.g.catppuccin_flavour = "macchiato"
  vim.cmd([[colorscheme catppuccin]])

  vim.cmd([[hi clear Folded]])
  vim.cmd([[hi clear NonText]])
  -- vim.cmd([[hi TabLine guibg=NONE guifg=#191b1f]])
  -- vim.cmd([[hi TabLineFill guibg=NONE guifg=#191b1f]])
  -- vim.cmd([[hi TabLineSel guibg=NONE guifg=#191b1f]])
  -- vim.cmd([[hi Title guibg=NONE guifg=#191b1f]])
end

return require("lib").module.create({
  name = "theme",
  plugins = {
    { "catppuccin/nvim", config = setup },
  },
})

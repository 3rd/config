-- Resources:
-- https://machineroom.purplekraken.com/posts/neovim-theme-lua/
-- https://www.locatelli.dev/nv-ide/
-- https://github.com/norcalli/nvim-base16.lua/blob/master/lua/base16.lua#L102

local setup = function()
  local catppuccin = require("catppuccin")
  local colors = require("catppuccin.palettes").get_palette()

  catppuccin.setup({
    transparent_background = true,
    term_colors = false,
    color_overrides = {
      all = {
        base = "#1f1f22",
        mantle = "#242424",
        crust = "#474747",
        overlay0 = "#7d7d7d",
        overlay1 = "#919191",
        overlay2 = "#a6a6a6",
        subtext0 = "#b5b5b5",
        subtext1 = "#b3b3b3",
        surface0 = "#383838", -- cursorline
        surface1 = "#4f4f4f", -- foldedbg
        surface2 = "#8f8f8f",
        text = "#D4D3DE",
        blue = "#63baff", -- status, foldedfg
        flamingo = "#ca71d9",
        green = "#ABD279",
        lavender = "#fba03c",
        maroon = "#be755a",
        mauve = "#be99ff",
        peach = "#ff8c07",
        pink = "#e91e63",
        red = "#ec8179",
        rosewater = "#ffdddd",
        sapphire = "#80c6ff",
        sky = "#ababab",
        teal = "#17cfbc",
        yellow = "#ffc505",
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
      treesitter = true,
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
      coc_nvim = false,
      lsp_trouble = false,
      cmp = true,
      lsp_saga = false,
      gitgutter = false,
      gitsigns = true,
      telescope = true,
      nvimtree = {
        enabled = true,
        show_root = false,
        transparent_panel = false,
      },
      neotree = {
        enabled = false,
        show_root = false,
        transparent_panel = false,
      },
      which_key = false,
      indent_blankline = {
        enabled = true,
        colored_indent_levels = false,
      },
      dashboard = false,
      neogit = false,
      vim_sneak = false,
      fern = false,
      barbar = false,
      bufferline = false,
      markdown = true,
      lightspeed = false,
      ts_rainbow = false,
      hop = false,
      notify = true,
      telekasten = false,
      symbols_outline = false,
    },
    custom_highlights = {
      VertSplit = { fg = "#474747" },
      -- NormalFloat = { bg = "NONE" },
      ["@slang.document.title"] = { fg = "#fba03c", style = { "bold" } },
      ["@slang.document.meta"] = { fg = "#fba03c" },
      ["@slang.document.meta.field"] = { fg = "#d2ced4" },
      ["@slang.document.meta.field.key"] = { fg = "#e3b959" },
      ["@slang.error"] = { bg = "#ff0000", fg = "#ffffff" },
      ["@slang.bold"] = { style = { "bold" } },
      ["@slang.italic"] = { style = { "italic" } },
      ["@slang.underline"] = { style = { "underline" } },
      ["@slang.comment"] = { fg = "#7d7d7d" },
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
      ["@slang.task_normal"] = { fg = "#d2ced4" },
      ["@slang.task_active"] = { fg = "#57CC99" },
      ["@slang.task_done"] = { fg = "#6a6a6a" },
      ["@slang.task_session"] = { fg = "#707070" },
      ["@slang.task_schedule"] = { fg = "#FF8000" },
      ["@slang.tag.hash"] = { fg = "#5BC0EB" },
      ["@slang.tag.positive"] = { fg = "#9BC53D" },
      ["@slang.tag.negative"] = { fg = "#FA4224" },
      ["@slang.tag.context"] = { fg = "#FDDC5C" },
      ["@slang.tag.danger"] = { bg = "#C3423F", fg = "#ffffff" },
      ["@slang.link_plain"] = { fg = "#5BC0CD", style = { "italic" } },
      ["@slang.link"] = { fg = "#5BC0CD", style = { "italic" } },
      -- ["@slang.code_block"] = { bg = "#202020" },
      ["@slang.code_block_start"] = { fg = "#707070", style = { "italic" } },
      ["@slang.code_block_language"] = { fg = "#808080", style = { "italic" } },
      ["@slang.code_block_content"] = { fg = "#d2ced4" },
      ["@slang.code_block_end"] = { fg = "#707070", style = { "italic" } },
    },
  })

  -- latte, frappe, macchiato, mocha
  vim.g.catppuccin_flavour = "macchiato"

  vim.cmd([[colorscheme catppuccin]])
  vim.cmd([[hi clear Folded]])
end

return require("lib").module.create({
  name = "theme",
  plugins = {
    { "catppuccin/nvim", config = setup },
  },
})

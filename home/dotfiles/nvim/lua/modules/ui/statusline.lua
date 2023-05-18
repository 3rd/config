local colors = {
  base = "#191923", -- background #191923 #1b1b22
  text = "#BDC7EE", -- foreground #BDC7EE #9CA5C9
  mantle = "#24252b", -- sidebar
  crust = "#54566b", -- VertSplit
  subtext0 = "#b4b9cc",
  subtext1 = "#c5cbe0",
  overlay0 = "#8588a6", -- PmenuThumb:bg, NonText, WildMenu
  overlay1 = "#9c9fba", -- Conceal
  overlay2 = "#9c9fba", -- Pmenu:fg
  surface0 = "#404152", -- CursorLine:bg, Pmenu:bg
  surface1 = "#525469", -- SignColumn:fg, Substitute:bg, LineNr:fg, PmenuSel:bg, PmenuSbar:bg, Visual:bg, Whitespace:bg
  surface2 = "#8588a6", -- Comment
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
}

local setup = function()
  local lualine = require("lualine")

  local theme = {
    normal = {
      a = { bg = colors.surface0, fg = colors.subtext0 },
      b = { bg = colors.surface1, fg = colors.subtext0 },
      c = { bg = colors.surface0, fg = colors.subtext1 },
    },
  }

  local components = {
    filename = { "filename", path = 1 },
    filetype = { "filetype", path = 1 },
    location = { "location" },
    progress = { "progress" },
    git_branch = { "branch" },
    git_diff = {
      "diff",
      color_added = colors.green,
      color_modified = colors.yellow,
      color_removed = colors.red,
    },
    diagnostics = {
      "diagnostics",
      sources = { "nvim_diagnostic" },
      symbols = { error = " ", warn = " ", info = " ", hint = "󰌶 " },
    },
  }

  local copilot_status = (function()
    if not require("modules/completion/copilot").enabled then return nil end

    local initialized = false
    local status = ""

    local setup_copilot_status = function()
      local ok, api = pcall(require, "copilot.api")
      if not ok then return end
      api.register_status_notification_handler(function(data)
        if data.status == "Normal" then
          status = ""
        elseif data.status == "InProgress" then
          status = "…"
        else
          status = data.status or "⦸"
        end
      end)
      initialized = true
    end

    return function()
      if not initialized then setup_copilot_status() end
      return status
    end
  end)()

  local sections = {
    lualine_a = { components.git_branch },
    lualine_b = { components.filename },
    lualine_c = { components.git_diff, components.diagnostics },
    lualine_x = { copilot_status },
    lualine_y = { components.filetype },
    lualine_z = { components.location },
  }

  lualine.setup({
    options = {
      theme = theme,
      icons_enabled = true,
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
      disabled_filetypes = { "NvimTree" },
      globalstatus = true,
    },
    sections = vim.deepcopy(sections),
    inactive_sections = vim.deepcopy(sections),
    tabline = {},
    extensions = { "nvim-tree" },
  })
end

return lib.module.create({
  name = "ui/statusline",
  plugins = {
    {
      "nvim-lualine/lualine.nvim",
      lazy = false,
      -- event = "VeryLazy",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = setup,
    },
    -- { "tjdevries/express_line.nvim" } -- alternative
  },
})

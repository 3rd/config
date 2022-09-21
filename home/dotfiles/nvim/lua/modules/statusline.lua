local setup = function()
  local lualine = require("lualine")

  local theme = {
    normal = {
      a = { bg = "#444444", fg = "#999999" },
      b = { bg = "#777777", fg = "#bbbbbb" },
      c = { bg = "#888888", fg = "#dddddd" },
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
      color_added = "#00ff00",
      color_modified = "#ffff00",
      color_removed = "#ff0000",
    },
    diagnostics = {
      "diagnostics",
      sources = { "nvim_diagnostic" },
      symbols = { error = " ", warn = " ", info = " ", hint = " " },
    },
  }

  local sections = {
    lualine_a = { components.git_branch },
    lualine_b = { components.filename },
    lualine_c = { components.git_diff, components.diagnostics },
    lualine_x = {},
    lualine_y = { components.filetype },
    lualine_z = { components.location, components.progress },
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

return require("lib").module.create({
  name = "statusline",
  plugins = {
    {
      "nvim-lualine/lualine.nvim",
      requires = { "kyazdani42/nvim-web-devicons" },
      config = setup,
    },
  },
})

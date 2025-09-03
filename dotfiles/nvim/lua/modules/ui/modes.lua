local colors = require("config/colors-hex")

return lib.module.create({
  name = "ui/modes",
  hosts = "*",
  plugins = {
    {
      "mvllow/modes.nvim",
      lazy = false,
      config = function()
        require("modes").setup({
          colors = {
            insert = colors.cyan,
            visual = "#c881de",
            copy = colors.common.cword,
            delete = colors.red,
          },
          line_opacity = 0.3,
          set_cursor = true,
          set_cursorline = true,
          set_number = true,
          ignore = { "NvimTree", "TelescopePrompt" },
        })
      end,
    },
  },
})

local colors = require("config/colors-hex")

return lib.module.create({
  name = "ui/modes",
  hosts = "*",
  plugins = {
    {
      "mvllow/modes.nvim",
      event = "VeryLazy",
      config = function()
        require("modes").setup({
          colors = {
            insert = colors.cyan,
            visual = colors.magenta,
            copy = colors.yellow,
            delete = colors.red,
          },
          line_opacity = 0.2,
          set_cursor = true,
          set_cursorline = true,
          set_number = true,
          ignore_filetypes = { "NvimTree", "TelescopePrompt" },
        })
      end,
    },
  },
})

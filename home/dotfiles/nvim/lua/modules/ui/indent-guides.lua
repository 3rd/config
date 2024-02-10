local colors = require("config/colors-hex")

return lib.module.create({
  name = "indent-guides",
  plugins = {
    {
      "shellRaining/hlchunk.nvim",
      event = "VeryLazy",
      -- https://github.com/shellRaining/hlchunk.nvim/blob/main/docs/en/indent.md
      config = function()
        local exclude_filetypes = require("hlchunk/utils/filetype").exclude_filetypes

        -- exclude
        local additional_excludes = {
          "fzf",
          "tsplayground",
          "text",
          "gitmessengerpopup",
          "bufferize",
        }

        for _, filetype in ipairs(additional_excludes) do
          exclude_filetypes[filetype] = true
        end

        local opts = {
          indent = {
            exclude_filetypes = exclude_filetypes,
            chars = { "│", "¦", "┆", "┊", "┊", "┊", "┊", "┊", "┊", "┊", "┊", "┊", "┊" }, -- │
            style = colors.plugins.indent_guides.indent,
          },
          chunk = {
            exclude_filetypes = exclude_filetypes,
            chars = {
              horizontal_line = "╴",
              vertical_line = "│",
              left_top = "╭",
              left_bottom = "╰",
              right_arrow = "▶",
            },
            style = colors.plugins.indent_guides.chunk,
          },
          blank = { enable = false },
          line_num = { enable = false },
        }

        require("hlchunk").setup(opts)
      end,
    },
  },
})

local colors = require("config/colors-hex")

return lib.module.create({
  name = "indent-guides",
  hosts = "*",
  plugins = {
    {
      "shellRaining/hlchunk.nvim",
      -- "3rd/hlchunk.nvim",
      event = "CursorHold",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "hlchunk.nvim"),
      -- https://github.com/shellRaining/hlchunk.nvim/blob/main/docs/en/indent.md
      config = function()
        local exclude_filetypes = require("hlchunk/utils/filetype").exclude_filetypes

        -- exclude
        local additional_excludes = {
          "bufferize",
          "fzf",
          "gitignore",
          "gitmessengerpopup",
          "snippets",
          "text",
          "tsplayground",
          "conf",
          "gitcommit",
          -- "syslang",
        }

        for _, filetype in ipairs(additional_excludes) do
          exclude_filetypes[filetype] = true
        end

        local opts = {
          indent = {
            enable = true,
            use_treesitter = false,
            exclude_filetypes = exclude_filetypes,
            chars = { "│", "¦", "┆", "┊", "┊", "┊", "┊", "┊", "┊", "┊", "┊", "┊", "┊" }, -- │
            style = colors.plugins.indent_guides.indent,
            delay = 200,
          },
          chunk = {
            enable = true,
            notify = false,
            exclude_filetypes = exclude_filetypes,
            use_treesitter = true,
            chars = {
              horizontal_line = "╴",
              vertical_line = "│",
              left_top = "╭",
              left_bottom = "╰",
              right_arrow = "▶",
            },
            style = colors.plugins.indent_guides.chunk,
            duration = 0,
            delay = 0,
          },
          blank = { enable = false },
          line_num = { enable = false },
        }

        require("hlchunk").setup(opts)
      end,
    },
  },
})

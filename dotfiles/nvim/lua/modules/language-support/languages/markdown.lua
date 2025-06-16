local setup = function()
  vim.g.markdown_fenced_languages = {
    "ts=typescript",
    "tsx=typescriptreact",
    "js=javascript",
    "jsx=javascriptreact",
  }
end

return lib.module.create({
  name = "language-support/languages/markdown",
  hosts = "*",
  setup = setup,
  plugins = {
    {
      "MeanderingProgrammer/render-markdown.nvim",
      enabled = false,
      ft = { "markdown" },
      ---@module 'render-markdown'
      ---@type render.md.UserConfig
      opts = {
        -- log_level = "debug",
        preset = "obsidian",
        file_types = { "markdown" },
        overrides = {
          buftype = {
            nofile = {
              render_modes = { "n", "c", "i" },
              -- render_modes = {},
              debounce = 5,
              code = {
                left_pad = 0,
                right_pad = 0,
                language_pad = 0,
              },
            },
          },
          filetype = {},
        },
        anti_conceal = {
          enabled = true,
          ignore = {
            code_background = false,
            sign = false,
          },
          above = 0,
          below = 0,
        },
        heading = {
          render_modes = true,
          -- Turn on / off heading icon & background rendering
          enabled = true,
          -- Turn on / off any sign column related rendering
          sign = true,
          -- Determines how icons fill the available space:
          --  inline:  underlying '#'s are concealed resulting in a left aligned icon
          --  overlay: result is left padded with spaces to hide any additional '#'
          position = "inline",
          -- Replaces '#+' of 'atx_h._marker'
          -- The number of '#' in the heading determines the 'level'
          -- The 'level' is used to index into the list using a cycle
          -- icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
          icons = function(ctx)
            local text = ""
            for i = 1, ctx.level do
              text = text .. "#"
            end
            return text .. " "
          end,
          -- Added to the sign column if enabled
          -- The 'level' is used to index into the list using a cycle
          signs = { "󰫎 " },
          -- Width of the heading background:
          --  block: width of the heading text
          --  full:  full width of the window
          -- Can also be a list of the above values in which case the 'level' is used
          -- to index into the list using a clamp
          width = "full",
          -- Amount of margin to add to the left of headings
          -- If a floating point value < 1 is provided it is treated as a percentage of the available window space
          -- Margin available space is computed after accounting for padding
          -- Can also be a list of numbers in which case the 'level' is used to index into the list using a clamp
          left_margin = 0,
          -- Amount of padding to add to the left of headings
          -- If a floating point value < 1 is provided it is treated as a percentage of the available window space
          -- Can also be a list of numbers in which case the 'level' is used to index into the list using a clamp
          left_pad = 0,
          -- Amount of padding to add to the right of headings when width is 'block'
          -- If a floating point value < 1 is provided it is treated as a percentage of the available window space
          -- Can also be a list of numbers in which case the 'level' is used to index into the list using a clamp
          right_pad = 0,
          -- Minimum width to use for headings when width is 'block'
          -- Can also be a list of integers in which case the 'level' is used to index into the list using a clamp
          min_width = 0,
          -- Determines if a border is added above and below headings
          border = true,
          -- Always use virtual lines for heading borders instead of attempting to use empty lines
          border_virtual = false,
          -- Highlight the start of the border using the foreground highlight
          border_prefix = false,
          -- Used above heading for border
          above = "▄",
          -- Used below heading for border
          below = "▀",
          -- The 'level' is used to index into the list using a clamp
          -- Highlight for the heading icon and extends through the entire line
          backgrounds = {
            "RenderMarkdownH1Bg",
            "RenderMarkdownH2Bg",
            "RenderMarkdownH3Bg",
            "RenderMarkdownH4Bg",
            "RenderMarkdownH5Bg",
            "RenderMarkdownH6Bg",
          },
          -- The 'level' is used to index into the list using a clamp
          -- Highlight for the heading and sign icons
          foregrounds = {
            "RenderMarkdownH1",
            "RenderMarkdownH2",
            "RenderMarkdownH3",
            "RenderMarkdownH4",
            "RenderMarkdownH5",
            "RenderMarkdownH6",
          },
        },
        bullet = {
          -- Turn on / off list bullet rendering
          enabled = true,
          -- Replaces '-'|'+'|'*' of 'list_item'
          -- How deeply nested the list is determines the 'level' which is used to index into the list using a cycle
          -- The item number in the list is used to index into the value using a clamp if the value is also a list
          -- If the item is a 'checkbox' a conceal is used to hide the bullet instead
          icons = { "⯄", "⭘", "🞆", "🞊" },
          ordered_icons = {},
          left_pad = 0,
          right_pad = 0,
          highlight = "RenderMarkdownBullet",
        },
        checkbox = {
          enabled = true,
          position = "inline",
          unchecked = {
            icon = "󰄱",
            highlight = "RenderMarkdownUnchecked",
            scope_highlight = nil,
          },
          checked = {
            icon = "󰱒",
            highlight = "RenderMarkdownChecked",
            scope_highlight = nil,
          },
          custom = {
            todo = { raw = "[-]", rendered = "󰥔 ", highlight = "RenderMarkdownTodo", scope_highlight = nil },
          },
        },
      },
    },
  },
})

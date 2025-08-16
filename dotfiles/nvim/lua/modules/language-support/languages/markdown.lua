local setup = function()
  vim.g.markdown_fenced_languages = {
    "ts=typescript",
    "tsx=typescriptreact",
    "js=javascript",
    "jsx=javascriptreact",
  }

  -- auto-enable text wrapping for markdown files
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function()
      vim.opt_local.wrap = true
      vim.opt_local.linebreak = true
      vim.opt_local.breakindent = true
    end,
  })
end

return lib.module.create({
  name = "language-support/languages/markdown",
  hosts = "*",
  setup = setup,
  plugins = {
    {
      "MeanderingProgrammer/render-markdown.nvim",
      -- enabled = true,
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
          enabled = true,
          setext = false,
          sign = false,
          position = "inline", -- inline, overlay
          -- icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
          -- icons = function(ctx)
          --   local text = ""
          --   for i = 1, ctx.level do
          --     text = text .. "#"
          --   end
          --   return text .. " "
          -- end,
          icons = { "▶ ", "▸ ", "▹ ", "‣ ", "• ", "· " },
          signs = { "󰫎 " },
          width = "full", -- block, full
          left_margin = 0,
          left_pad = 0,
          right_pad = 0,
          min_width = 0,
          border = true,
          border_virtual = false,
          border_prefix = false,
          above = "▄",
          below = "▀",
          backgrounds = {
            "RenderMarkdownH1Bg",
            "RenderMarkdownH2Bg",
            "RenderMarkdownH3Bg",
            "RenderMarkdownH4Bg",
            "RenderMarkdownH5Bg",
            "RenderMarkdownH6Bg",
          },
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
          enabled = true,
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
        code = {
          enabled = true,
          render_modes = false,
          sign = false,
          conceal_delimiters = true,
          language = true,
          position = "left",
          language_icon = true,
          language_name = true,
          language_info = true,
          language_pad = 0,
          disable_background = { "diff" },
          width = "block", -- block, full
          left_margin = 0,
          left_pad = 1,
          right_pad = 1,
          min_width = 0,
          border = "thin", -- none, thick, thin, hide
          language_border = "█",
          language_left = "",
          language_right = "",
          above = "▄",
          below = "▀",
          inline = true,
          inline_left = "",
          inline_right = "",
          inline_pad = 0,
          highlight = "RenderMarkdownCode",
          highlight_info = "RenderMarkdownCodeInfo",
          highlight_language = nil,
          highlight_border = "RenderMarkdownCodeBorder",
          highlight_fallback = "RenderMarkdownCodeFallback",
          highlight_inline = "RenderMarkdownCodeInline",
          style = "full", -- none, normal, language, full
        },
      },
    },
  },
})

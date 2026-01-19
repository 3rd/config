local shared_config = {
  headline_highlights = { "Headline1", "Headline2", "Headline3", "Headline4", "Headline5", "Headline6" },
  codeblock_highlight = "CodeBlock",
  dash_highlight = "Dash",
  dash_string = "-",
  doubledash_highlight = "DoubleDash",
  doubledash_string = "=",
  quote_highlight = "Quote",
  quote_string = "┃",
  fat_headlines = false,
  fat_headline_upper_string = "▃",
  fat_headline_lower_string = "🬂",
}

return lib.module.create({
  name = "headlines",
  -- enabled = false,
  hosts = "*",
  plugins = {
    {
      "lukas-reineke/headlines.nvim",
      ft = {
        "syslang",
        -- "markdown",
      },
      dependencies = {
        "nvim-treesitter/nvim-treesitter",
        branch = "master",
      },
      config = function()
        local headlines = require("headlines")

        headlines.setup({
          -- markdown = shared_config,
          syslang = vim.tbl_extend("force", shared_config, {
            bullet_highlights = {},
            query = vim.treesitter.query.parse(
              "syslang",
              [[
              [
                (heading_1_marker)
                (heading_2_marker)
                (heading_3_marker)
                (heading_4_marker)
                (heading_5_marker)
                (heading_6_marker)
              ] @headline

              (horizontal_rule) @dash
              (double_horizontal_rule) @doubledash
              (banner) @quote
              ((code_block) @codeblock (#offset! @codeblock 0 0 1 0))
            ]]
            ),
          }),
        })
      end,
    },
  },
})

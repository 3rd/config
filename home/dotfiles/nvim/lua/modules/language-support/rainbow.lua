return lib.module.create({
  name = "misc/rainbow",
  -- enabled = false,
  plugins = {
    {
      "HiPhish/rainbow-delimiters.nvim",
      event = "VimEnter",
      config = function()
        local rainbow = require("rainbow-delimiters")

        require("rainbow-delimiters.setup").setup({
          strategy = {
            [""] = rainbow.strategy["global"],
            -- [""] = rainbow.strategy["local"],
          },
          highlight = {
            "RainbowRed",
            "RainbowYellow",
            "RainbowBlue",
            "RainbowOrange",
            "RainbowGreen",
            "RainbowViolet",
            "RainbowCyan",
          },
          blacklist = { "c", "cpp" },
        })
      end,
    },
  },
})

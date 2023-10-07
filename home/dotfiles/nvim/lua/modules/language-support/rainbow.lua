return lib.module.create({
  -- https://github.com/HiPhish/rainbow-delimiters.nvim/issues/36
  -- enabled = false,
  name = "misc/rainbow",
  plugins = {
    {
      "HiPhish/rainbow-delimiters.nvim",
      event = "VimEnter",
      config = function()
        local rainbow = require("rainbow-delimiters")

        require("rainbow-delimiters.setup")({
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

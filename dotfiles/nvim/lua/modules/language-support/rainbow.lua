return lib.module.create({
  name = "misc/rainbow",
  -- enabled = false,
  hosts = "*",
  plugins = {
    {
      "HiPhish/rainbow-delimiters.nvim",
      event = "CursorHold",
      config = function()
        local rainbow = require("rainbow-delimiters")

        -- https://github.com/HiPhish/rainbow-delimiters.nvim/issues/12
        local get_strategy = function()
          local max_errors = 100
          local count = 0
          vim.treesitter.get_parser():for_each_tree(function(lt)
            if lt:root():has_error() then count = count + 1 end
          end)
          if count > max_errors then return nil end
          return rainbow.strategy["global"]
        end

        require("rainbow-delimiters.setup").setup({
          strategy = {
            [""] = get_strategy,
          },
          query = {
            [""] = "rainbow-delimiters",
            ["lua"] = "rainbow-blocks",
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
          blacklist = {
            "c",
            "cpp",
            "comment",
            -- "lua",
          },
        })
        vim.api.nvim_exec2("edit", {})
      end,
    },
  },
})

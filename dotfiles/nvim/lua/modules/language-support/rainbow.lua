return lib.module.create({
  name = "misc/rainbow",
  -- enabled = false,
  hosts = "*",
  plugins = {
    {
      "HiPhish/rainbow-delimiters.nvim",
      lazy = false,
      config = function()
        local rainbow = require("rainbow-delimiters")

        -- https://github.com/HiPhish/rainbow-delimiters.nvim/issues/12
        local get_strategy = function(bufnr)
          local max_errors = 100
          local count = 0
          -- rainbow-delimiters passes the buffer being attached here.
          local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
          if not ok or not parser then return nil end
          parser:for_each_tree(function(lt)
            if lt:root():has_error() then count = count + 1 end
          end)
          if count > max_errors then return nil end
          return rainbow.strategy["global"]
        end

        local has_parser = function(bufnr)
          local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
          return ok and parser ~= nil
        end

        require("rainbow-delimiters.setup").setup({
          condition = has_parser,
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
            "lua",
            "syslang",
          },
        })
      end,
    },
  },
})

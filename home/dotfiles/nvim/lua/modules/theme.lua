return lib.module.create({
  name = "theme",
  setup = function()
    vim.cmd([[colorscheme static]])
  end,
  plugins = {
    {
      "rktjmp/lush.nvim",
      -- event = "VeryLazy",
      cmd = { "Lushify" },
      dependencies = { "rktjmp/shipwright.nvim" },
      config = function()
        log("~> dynamic")
        vim.cmd([[colorscheme dynamic]])
      end,
    },
  },
  actions = {
    {
      "n",
      "Build theme",
      function()
        -- colors/theme.lua
        local shipwright = require("shipwright")
        local lush = require("shipwright.transform.lush")
        local patchwrite = require("shipwright.transform.patchwrite")
        local path_to_output = lib.path.resolve(lib.env.dirs.vim.config .. "/colors/static.lua")
        log("Building theme...")
        shipwright.run(
          require("config/theme"),
          lush.to_lua,
          { patchwrite, path_to_output, "-- PATCH_OPEN", "-- PATCH_CLOSE" }
        )
        -- config/colors-hex.lua
        log("Writing colors...")
        local colors = require("config/colors")
        local function parse(part)
          local result = {}
          for key, value in pairs(part) do
            if type(value) == "string" then
              result[key] = value
            elseif type(value.hex) == "string" then
              result[key] = value.hex
            else
              result[key] = parse(value)
            end
          end
          return result
        end
        local hex_colors = parse(colors)
        local lua_colors = vim.inspect(hex_colors)
        local colors_path = vim.fn.stdpath("config") .. "/lua/config/colors-hex.lua"
        lib.fs.file.write(colors_path, "return " .. lua_colors)
        log("Theme built!")
      end,
    },
  },
})

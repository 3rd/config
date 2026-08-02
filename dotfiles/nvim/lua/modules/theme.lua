local colors = require("config/colors-hex")

local apply_terminal_colors = function()
  for index = 0, 15 do
    local color = colors.terminal[index + 1]
    if not color then error(string.format("Missing terminal color %d", index)) end
    vim.g["terminal_color_" .. index] = color
  end
end

return lib.module.create({
  name = "theme",
  hosts = "*",
  setup = function()
    vim.cmd([[colorscheme static]])
    apply_terminal_colors()
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
        -- colors/static.lua
        local shipwright = require("shipwright")
        local lush = require("shipwright.transform.lush")
        local patchwrite = require("shipwright.transform.patchwrite")
        package.loaded["config/palette"] = nil
        package.loaded["config/theme"] = nil
        local theme = require("config/theme")
        local path_to_output = lib.path.resolve(lib.env.dirs.vim.config .. "/colors/static.lua")
        log("Building theme...")
        shipwright.run(theme, lush.to_lua, { patchwrite, path_to_output, "-- PATCH_OPEN", "-- PATCH_CLOSE" })
        -- config/colors-hex.lua
        log("Writing colors...")
        local colors = theme.colors

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
        local palette = require("config/palette")
        local base_palette_keys = {
          blue = "blue-medium",
          cyan = "cyan-medium",
          foreground = "foreground",
          green = "green-medium",
          indigo = "indigo-medium",
          magenta = "magenta-medium",
          orange = "orange-medium",
          pink = "magenta-light",
          red = "red-medium",
          visual = "selection-background",
          yellow = "yellow-medium",
        }
        for color_name, palette_name in pairs(base_palette_keys) do
          hex_colors[color_name] = palette[palette_name]
        end

        local template = [[
-- base colors
local colors = %s

return colors]]

        local colors_content = string.format(template, vim.inspect(hex_colors))
        local colors_path = vim.fn.stdpath("config") .. "/lua/config/colors-hex.lua"
        lib.fs.file.write(colors_path, colors_content)
        log("Theme built!")
      end,
    },
  },
})

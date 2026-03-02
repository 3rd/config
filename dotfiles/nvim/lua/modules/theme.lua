return lib.module.create({
  name = "theme",
  hosts = "*",
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
        -- colors/static.lua
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
        local colors = require("config/theme").colors
        local hostname = vim.uv.os_gethostname()

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
        local template = [[
local hostname = vim.uv.os_gethostname()

-- base colors
local colors = %s

-- host-specific overrides
if hostname == "death" then
-- colors.ui = {
--   breadcrumbs = {
--     normal = {
--       fg = "#A29CBF"
--     },
--     separator = {
--       fg = "#8D87AB"
--     }
--   },
--   line = {
--     current_line = {
--     },
--     current_line_nr = {
--       bg = "#3A3748",
--       fg = "#8D89A4"
--     },
--     current_line_sign = {
--       bg = "#3A3748",
--       fg = "#ED9A5E"
--     },
--     line_nr = {
--       fg = "#4F4B62"
--     }
--   },
--   split = "#312F3D",
--   status = {
--     a = {
--       bg = "#312F3D",
--       fg = "#BBB6D2"
--     },
--     b = {
--       bg = "#211F2D",
--       fg = "#ACA6C9"
--     },
--     c = {
--       bg = "#110F18",
--       fg = "#A29CBF"
--     }
--   }
-- }
end
return colors]]

        local colors_content = string.format(template, vim.inspect(hex_colors))
        local colors_path = vim.fn.stdpath("config") .. "/lua/config/colors-hex.lua"
        lib.fs.file.write(colors_path, colors_content)
        log("Theme built!")
      end,
    },
  },
})

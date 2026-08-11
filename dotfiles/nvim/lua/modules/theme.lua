local BASE_PALETTE_KEYS = {
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

local apply_terminal_colors = function()
  local colors = require("config/colors-hex")
  for index = 0, 15 do
    local color = colors.terminal[index + 1]
    if not color then error(string.format("Missing terminal color %d", index)) end
    vim.g["terminal_color_" .. index] = color
  end
end

local function convert_colors_to_hex(part)
  local result = {}
  for key, value in pairs(part) do
    if type(value) == "string" then
      result[key] = value
    elseif type(value.hex) == "string" then
      result[key] = value.hex
    else
      result[key] = convert_colors_to_hex(value)
    end
  end
  return result
end

local render_static_colors = function(theme, static_colors_path)
  local shipwright = require("shipwright")
  local lush = require("shipwright.transform.lush")
  local patchwrite = require("shipwright.transform.patchwrite")
  local temporary_path = vim.fn.tempname()
  lib.fs.file.write(temporary_path, lib.fs.file.read(static_colors_path))

  local ok, content_or_error = xpcall(function()
    shipwright.run(theme, lush.to_lua, {
      patchwrite,
      temporary_path,
      "-- PATCH_OPEN",
      "-- PATCH_CLOSE",
    })
    return lib.fs.file.read(temporary_path)
  end, debug.traceback)

  vim.uv.fs_unlink(temporary_path)
  if not ok then error(content_or_error) end
  return content_or_error
end

local render_hex_colors = function(theme)
  local hex_colors = convert_colors_to_hex(theme.colors)
  local palette = require("config/palette")
  for color_name, palette_name in pairs(BASE_PALETTE_KEYS) do
    hex_colors[color_name] = palette[palette_name]
  end

  return string.format(
    [[
-- base colors
local colors = %s

return colors]],
    vim.inspect(hex_colors)
  )
end

local render_theme_artifacts = function()
  package.loaded["config/palette"] = nil
  package.loaded["config/theme"] = nil

  local theme = require("config/theme")
  local config_path = lib.env.dirs.vim.config
  local static_colors_path = lib.path.resolve(config_path, "colors/static.lua")
  local hex_colors_path = lib.path.resolve(config_path, "lua/config/colors-hex.lua")

  return {
    {
      path = static_colors_path,
      content = render_static_colors(theme, static_colors_path),
    },
    {
      path = hex_colors_path,
      content = render_hex_colors(theme),
    },
  }
end

local build_theme = function()
  log("Building theme...")
  local artifacts = render_theme_artifacts()
  for _, artifact in ipairs(artifacts) do
    lib.fs.file.write(artifact.path, artifact.content)
  end
  log("Theme built!")
end

local check_theme = function()
  local stale_paths = {}
  for _, artifact in ipairs(render_theme_artifacts()) do
    if lib.fs.file.read(artifact.path) ~= artifact.content then stale_paths[#stale_paths + 1] = artifact.path end
  end

  if #stale_paths > 0 then error("Theme artifacts are stale:\n" .. table.concat(stale_paths, "\n")) end
  log("Theme artifacts are current")
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
      build_theme,
    },
  },
  exports = {
    build = build_theme,
    check = check_theme,
  },
})

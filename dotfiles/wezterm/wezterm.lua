local wezterm = require("wezterm")
local installed_colors_path = wezterm.home_dir .. "/.config/theme/colors.json"
local repository_colors_path = wezterm.config_dir .. "/../../home-manager/colors.nix"
local palette_loader = dofile(wezterm.config_dir .. "/../theme/palette.lua")

local colors_path = repository_colors_path
local palette = palette_loader.load_nix(colors_path)
if not palette then
  colors_path = installed_colors_path
  palette = palette_loader.load_json(colors_path, wezterm.json_parse)
end
if not palette then
  error("Could not find theme palette at " .. installed_colors_path .. " or " .. repository_colors_path)
end

wezterm.add_to_config_reload_watch_list(colors_path)

return {
  automatically_reload_config = true,
  adjust_window_size_when_changing_font_size = false,
  hide_tab_bar_if_only_one_tab = true,
  max_fps = 144,
  animation_fps = 1,

  enable_tab_bar = false,
  enable_kitty_graphics = true,

  allow_square_glyphs_to_overflow_width = "Never",
  freetype_load_target = "HorizontalLcd",
  freetype_render_target = "HorizontalLcd",
  use_cap_height_to_scale_fallback_fonts = true,
  warn_about_missing_glyphs = false,

  window_decorations = "NONE",
  window_background_opacity = 0.8,
  window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
  },

  audible_bell = "Disabled",
  visual_bell = {
    fade_in_duration_ms = 5,
    fade_out_duration_ms = 5,
    target = "CursorColor",
  },

  -- default_cursor_style = "SteadyBlock",
  cursor_blink_rate = 400,
  default_cursor_style = "BlinkingBlock",
  force_reverse_video_cursor = true,

  hyperlink_rules = {},
  disable_default_key_bindings = true,
  keys = {
    { key = "c", mods = "CTRL|SHIFT", action = wezterm.action({ CopyTo = "Clipboard" }) },
    { key = "v", mods = "CTRL|SHIFT", action = wezterm.action({ PasteFrom = "Clipboard" }) },
    { key = "phys:Equal", mods = "CTRL|SHIFT", action = "IncreaseFontSize" },
    { key = "phys:Minus", mods = "CTRL|SHIFT", action = "DecreaseFontSize" },
    { key = "phys:Backspace", mods = "CTRL|SHIFT", action = "ResetFontSize" },
  },

  font = wezterm.font_with_fallback({
    "MonoLisa",
    "Input Mono",
    "Hasklig",
    "Fira Code",
    "Noto Color Emoji",
  }),
  font_size = 12,
  line_height = 1,

  colors = {
    background = palette.background,
    foreground = palette.foreground,
    cursor_fg = palette.background,
    cursor_bg = palette.cursor,
    cursor_border = palette.cursor,
    selection_bg = palette["selection-background"],
    selection_fg = palette["selection-foreground"],
    scrollbar_thumb = palette["gray-darker"],
    split = palette["gray-darkish"],
    ansi = {
      palette.color0,
      palette.color1,
      palette.color2,
      palette.color3,
      palette.color4,
      palette.color5,
      palette.color6,
      palette.color7,
    },
    brights = {
      palette.color8,
      palette.color9,
      palette.color10,
      palette.color11,
      palette.color12,
      palette.color13,
      palette.color14,
      palette.color15,
    },
  },
}

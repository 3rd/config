local wezterm = require("wezterm")

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
    "Input Mono",
    "BMono",
    "Hasklig",
    "Fira Code",
    "Noto Color Emoji",
  }),
  font_size = 12,
  line_height = 1,

  -- colors = {
  --   foreground = "#c5c5c5",
  --   background = "#141414",
  --   cursor_fg = "#ffffff",
  --   cursor_bg = "#d78700",
  --   cursor_border = "#d78700",
  --   selection_fg = "#000000",
  --   selection_bg = "#fffacd",
  --   ansi = { "#000000", "#b22222", "#008000", "#999900", "#0066ff", "#ba55d3", "#009999", "#dddddd" },
  --   brights = { "#808080", "#df0000", "#00d700", "#ffd700", "#5f87ff", "#875faf", "#00ffff", "#ffffff" },
  -- },
  colors = {
    background = "#191b1f",
    -- foreground = "#e3e5e8",
    foreground = "#d3d5d8",
    cursor = "#f2b90d",
    cursor_fg = "#191b1f",
    cursor_bg = "#ffffff",
    cursor_border = "#eeeeee",
    selection_bg = "#303233",
    selection_fg = "#cacecd",
    scrollbar_thumb = "#16161d",
    split = "#16161d",
    ansi = {
      "#282c34",
      "#c2290a",
      "#66b814",
      "#f2b90d",
      "#06a8f9",
      "#e06ef7",
      "#0ac2c2",
      "#d5d7dd",
    },
    brights = {
      "#595e68",
      "#f2330d",
      "#80e619",
      "#f5c73d",
      "#38b9fa",
      "#eb9efa",
      "#0df2f2",
      "#e3e5e8",
    },
  },

  -- color_scheme = "Tinacious Design (Dark)",
  -- color_scheme = "Vice Alt (base16)",
  -- color_scheme = "Vice Dark (base16)",
  -- color_scheme = "Violet Dark",
  color_scheme = "VSCodeDark+ (Gogh)",
}
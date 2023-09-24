local lush = require("lush")
local hsl = lush.hsl

local colors = {
  none = "NONE",
  background = hsl(230, 15, 14),
  foreground = hsl(230, 60, 85),
  blue = hsl(200, 95, 60),
  cyan = hsl(180, 70, 55),
  green = hsl(90, 60, 60),
  indigo = hsl(270, 100, 75),
  magenta = hsl(320, 80, 70),
  orange = hsl(15, 90, 65),
  pink = hsl(320, 75, 70),
  red = hsl(355, 60, 60),
  yellow = hsl(30, 80, 60),
}

local variable = colors.foreground
local property = variable.darken(12).desaturate(10)
local keyword = hsl(270, 70, 75)

colors.common = {
  -- lab
  identifier = variable,
  constant = colors.pink,
  keyword = keyword,
  property = property,
  field = property,
  -- base
  operator = colors.foreground.darken(30).desaturate(20),
  ["function"] = colors.blue,
  type = colors.cyan,
  parameter = colors.yellow,
  -- comment = colors.orange.desaturate(75).darken(35),
  comment = colors.foreground.desaturate(60).darken(35),
  delimiter = colors.foreground.darken(40).desaturate(65),
  boolean = colors.pink,
  number = colors.pink,
  string = colors.green,
  -- control
  conditional = keyword,
  ["repeat"] = keyword,
  special_keyword = keyword,
  -- extra
  builtin = colors.red,
  macro = keyword,
  constructor = colors.blue.lighten(10).desaturate(10),
}

colors.slang = {
  document = {
    title = colors.orange,
    meta = colors.yellow,
    meta_field = colors.magenta,
    meta_field_key = colors.pink,
  },
  bold = "#C1D1FF",
  string = "#4efa8e",
  number = "#71c9f6",
  ticket = "#fa89f6",
  datetime = "#FC824A",
  code = {
    inline = colors.orange.desaturate(10).lighten(10),
    block = {
      background = colors.background.lighten(5),
      marker = colors.background.lighten(20),
      language = colors.background.lighten(30),
      content = colors.foreground,
    },
  },
  link = {
    internal = "#5BC0CD",
    external = "#5db4e3",
  },
  heading = {
    one = "#9999FF",
    two = "#C08FFF",
    three = "#E38FFF",
    four = "#FFC78F",
    five = "#04D3D0",
    six = "#f0969f",
  },
  section = "#04D3D0",
  banner = {
    -- bg = "#262C3",
    bg = "#38425B",
    fg = "#A9B9E5", -- #8797C2
  },
  task = {
    default = colors.foreground.darken(20),
    active = colors.cyan,
    done = colors.common.comment,
    cancelled = "#fa4040",
    session = "#7378a5",
    schedule = "#7378a5",
  },
  tag = {
    hash = "#5BC0EB",
    positive = "#9BC53D",
    negative = "#FA4224",
    context = colors.yellow,
    danger = { bg = "#C3423F", fg = "#ffffff" },
    identifier = "#e38fff",
  },
  list_item = {
    -- item = colors.foreground.desaturate(20).darken(10),
    marker = colors.foreground.desaturate(80).darken(40),
    label = colors.yellow.lighten(20).saturate(30), -- "#c881de",
    label_marker = colors.common.comment,
  },
  label = colors.yellow,
}

colors.rainbow = {
  red = colors.red.darken(25).desaturate(60),
  yellow = colors.yellow.darken(25).desaturate(60),
  blue = colors.blue.darken(25).desaturate(60),
  orange = colors.orange.darken(25).desaturate(60),
  green = colors.green.darken(25).desaturate(60),
  violet = colors.magenta.darken(25).desaturate(60),
  cyan = colors.cyan.darken(25).desaturate(60),
}

colors.ui = {
  surface0 = colors.background.lighten(10),
  surface1 = colors.background.lighten(15),
  surface2 = colors.background.lighten(20),
  subtext0 = colors.foreground.darken(10),
  subtext1 = colors.foreground.darken(20),
  yellow = colors.yellow,
  green = colors.green,
  red = colors.red,
}

return colors

local lush = require("lush")
local hsl = lush.hsl

-- What I want to see:
-- - keywords
-- - identifiers
-- - functions
-- - literal values (except strings)
-- - types
-- Groups:
-- - things that hold values
-- - values
-- - control flow
-- - function calls

local base_hue = 245

local colors = {
  none = "NONE",
  background = hsl(base_hue, 15, 15),
  foreground = hsl(base_hue, 30, 80),
  blue = hsl(205, 100, 65),
  cyan = hsl(185, 70, 50),
  green = hsl(80, 45, 60),
  indigo = hsl(270, 100, 75),
  magenta = hsl(320, 80, 70),
  orange = hsl(15, 70, 70),
  pink = hsl(320, 70, 70),
  red = hsl(350, 75, 60),
  yellow = hsl(40, 85, 65),
}

local variable = colors.foreground.darken(5).saturate(10)
local property = variable.darken(5).desaturate(20)
local keyword = hsl(275, 65, 70)
-- local control = colors.orange

colors.common = {
  -- lab
  identifier = variable,
  constant = variable,
  keyword = keyword,
  property = property,
  -- base
  operator = colors.foreground.darken(30).desaturate(20),
  ["function"] = colors.blue,
  type = colors.cyan,
  -- field = colors.orange.desaturate(50).lighten(20),
  field = property,
  parameter = colors.yellow.darken(15).desaturate(20),
  -- comment = colors.orange.desaturate(70).darken(40),
  comment = colors.foreground.desaturate(50).darken(40),
  delimiter = colors.foreground.darken(40).desaturate(45),
  boolean = colors.pink,
  number = colors.pink,
  string = colors.green,
  -- control
  conditional = keyword,
  ["repeat"] = keyword,
  special_keyword = keyword,
  -- extra
  builtin = colors.red.rotate(-10).desaturate(20),
  macro = colors.red.rotate(-20).desaturate(30),
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
      background = "#2f3041",
      marker = "#7378a5",
      language = "#6F75A9",
      content = "#BDC7EE",
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
    schedule = "#FF8000",
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
  label = colors.yellow.lighten(20).saturate(30),
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

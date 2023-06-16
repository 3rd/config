local lush = require("lush")
local hsl = lush.hsl

local base_hue = 230

local colors = {
  none = "NONE",
  background = hsl(base_hue, 15, 15),
  foreground = hsl("#ADBDEB"),
  primary = hsl(base_hue, 90, 80),
  blue = hsl(200, 90, 60),
  magenta = hsl(280, 80, 80),
  green = hsl(80, 50, 60),
  orange = hsl(30, 95, 60),
  pink = hsl(330, 80, 70),
  red = hsl(5, 75, 60),
  yellow = hsl(40, 85, 60),
  cyan = hsl(180, 70, 60),
}

colors.common = {
  identifier = colors.foreground.darken(10),
  operator = colors.foreground.darken(30).desaturate(40),
  keyword = colors.magenta.darken(5),
  ["function"] = colors.blue,
  type = colors.cyan,
  field = colors.foreground.darken(20).desaturate(30),
  comment = hsl(base_hue, 20, 55),
  delimiter = colors.foreground.darken(35).desaturate(50),
  constructor = colors.magenta.lighten(10).desaturate(10),
  conditional = colors.red.desaturate(10).rotate(20),
  constant = colors.foreground.darken(10).saturate(40),
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
    -- one = colors.primary,
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
    marker = colors.primary.desaturate(80).darken(40),
    label = colors.yellow.lighten(20).saturate(30), -- "#c881de",
    label_marker = colors.common.comment,
  },
  label = colors.yellow.lighten(20).saturate(30),
}

colors.rainbow = {
  one = hsl(250, 60, 70),
  two = hsl(290, 65, 70),
  three = hsl(330, 70, 70),
  four = hsl(10, 60, 70),
  five = hsl(40, 60, 70),
  six = hsl(150, 40, 60),
  seven = hsl(190, 65, 70),
}

return colors

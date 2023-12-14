local lush = require("lush")
local hsl = lush.hsl

local colors = {
  none = "NONE",
  background = hsl(230, 15, 16),
  foreground = hsl(230, 60, 80),
  blue = hsl(200, 85, 60),
  cyan = hsl(180, 60, 52),
  green = hsl(90, 40, 55),
  indigo = hsl(270, 80, 75),
  magenta = hsl(320, 80, 70),
  orange = hsl(20, 90, 62),
  pink = hsl(310, 60, 70),
  red = hsl(0, 80, 65),
  yellow = hsl(38, 80, 60),
}

local variable = colors.foreground
local property = variable.darken(7).saturation(60)
local keyword = colors.foreground.darken(20).desaturate(40)
local control = colors.indigo

colors.common = {
  -- lab
  identifier = variable,
  constant = colors.pink,
  keyword = keyword,
  property = property,
  field = property,
  -- base
  operator = colors.foreground.darken(30).saturation(30),
  ["function"] = colors.blue,
  type = colors.cyan,
  parameter = colors.yellow.darken(10).desaturate(20),
  -- comment = colors.orange.desaturate(75).darken(35),
  comment = colors.foreground.desaturate(65).darken(35),
  delimiter = colors.foreground.darken(40).desaturate(65),
  boolean = colors.pink,
  number = colors.pink,
  string = colors.green,
  -- control
  conditional = control,
  ["repeat"] = control,
  special_keyword = control,
  -- extra
  builtin = colors.orange,
  macro = keyword.lighten(40).saturate(70),
  ret = colors.red,
  constructor = colors.blue.lighten(10).desaturate(10),
  cword = colors.background.lighten(20),
}

colors.slang = {
  document = {
    title = colors.green.lighten(20).saturation(70),
    meta = colors.yellow,
    meta_field = colors.magenta,
    meta_field_key = colors.pink,
  },
  bold = colors.foreground.lighten(20),
  string = colors.orange.desaturate(40).darken(10),
  number = colors.common.number,
  ticket = "#fa89f6",
  datetime = "#FC824A",
  code = {
    inline = colors.orange.desaturate(10).lighten(10),
    block = {
      background = colors.background.lighten(10),
      marker = colors.background.lighten(20),
      language = colors.background.lighten(30),
      content = colors.foreground,
    },
  },
  link = {
    internal = "#5BC0CD",
    external = colors.blue.darken(10).desaturate(20),
  },
  heading = {
    one = hsl("#9999FF"),
    two = hsl("#C08FFF"),
    three = hsl("#E38FFF"),
    four = hsl("#FFC78F"),
    five = hsl("#04D3D0"),
    six = hsl("#f0969f"),
  },
  section = "#8797C2",
  banner = {
    -- bg = "#262C3",
    bg = "#38425B",
    fg = "#A9B9E5", -- #8797C2
  },
  task = {
    default = colors.foreground,
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
    label = colors.indigo.lighten(10).saturate(20), -- "#c881de",
    label_marker = colors.common.comment.darken(30),
  },
  label = colors.orange.desaturate(20),
}

colors.rainbow = {
  red = colors.red.darken(20).desaturate(40),
  yellow = colors.yellow.darken(20).desaturate(40),
  blue = colors.blue.darken(20).desaturate(40),
  orange = colors.orange.darken(20).desaturate(40),
  green = colors.green.darken(20).desaturate(40),
  violet = colors.magenta.darken(20).desaturate(40),
  cyan = colors.cyan.darken(20).desaturate(40),
}

colors.ui = {
  line = {
    line_nr = { fg = colors.background.lighten(20) },
    current_line = { bg = colors.background.lighten(10) },
    current_line_nr = { bg = colors.background.lighten(10), fg = colors.background.lighten(50) },
    current_line_sign = { bg = colors.background.lighten(10), fg = colors.orange },
  },
  split = colors.background.lighten(5),
  status = {
    a = { bg = colors.background.lighten(15), fg = colors.foreground.darken(10).desaturate(20) },
    b = { bg = colors.background.lighten(10), fg = colors.foreground.darken(15).desaturate(20) },
    c = { bg = colors.background.lighten(5), fg = colors.foreground.darken(20).desaturate(30) },
  },
  breadcrumbs = {
    normal = { bg = colors.background.lighten(5), fg = colors.foreground.darken(20).desaturate(30) },
    separator = { fg = colors.foreground.darken(30).desaturate(40) },
  },
}

colors.plugins = {
  indent_guides = {
    indent = { colors.background.lighten(10) },
    chunk = colors.magenta.darken(40).desaturate(40),
  },
}

return colors

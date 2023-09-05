local lush = require("lush")
local hsluv = lush.hsluv
local hsl = lush.hsl

local gen = function(hue)
  local background = hsluv(hue, 20, 13)
  local foreground = hsluv(hue, 20, 70)

  -- identifiers
  local variable = foreground
  local constant = variable
  local property = foreground.abs_darken(10).abs_desaturate(5)
  local field = foreground.abs_darken(10).abs_saturate(10)
  local parameter = foreground.rotate(130).abs_darken(10).saturation(65)
  -- control
  local keyword = foreground.rotate(20).saturation(75).lightness(65)
  local operator = foreground.rotate(75).saturation(50).lightness(55)
  local func = foreground.rotate(-30).saturation(90).lightness(75)
  local conditional = keyword
  local loop = keyword
  local special_keyword = keyword.saturation(100).lightness(70)
  -- types
  local type = foreground.rotate(290).abs_saturate(40).abs_darken(5)
  local boolean = foreground.rotate(165).abs_saturate(80)
  local number = boolean
  local string = foreground.rotate(210).saturation(75).lightness(75)
  -- misc
  local comment = foreground.rotate(130).abs_darken(25).abs_desaturate(100)
  local delimiter = foreground.abs_darken(30).abs_desaturate(45)
  -- special
  local builtin = foreground.rotate(105).saturation(70).lightness(60)
  local macro = foreground.rotate(40).abs_darken(5).abs_saturate(20)
  local constructor = func

  local out = {
    -- temp
    blue = hsl(200, 90, 60),
    cyan = hsl(180, 70, 60),
    green = hsl(90, 60, 55),
    indigo = hsl(270, 100, 75),
    magenta = hsl(320, 80, 70),
    orange = hsl(15, 90, 65),
    pink = hsl(320, 75, 70),
    red = hsl(355, 60, 60),
    yellow = hsl(40, 95, 70),
    -- base
    background = background,
    foreground = foreground,
    -- common
    common = {
      -- identifiers
      identifier = variable,
      constant = constant,
      property = property,
      field = field,
      parameter = parameter,
      -- control
      keyword = keyword,
      operator = operator,
      ["function"] = func,
      conditional = conditional,
      ["repeat"] = loop,
      special_keyword = special_keyword,
      -- types
      type = type,
      boolean = boolean,
      number = number,
      string = string,
      -- misc
      comment = comment,
      delimiter = delimiter,
      -- special
      builtin = builtin,
      macro = macro,
      constructor = constructor,
    },
  }

  out.slang = {
    document = {
      title = out.orange,
      meta = out.yellow,
      meta_field = out.magenta,
      meta_field_key = out.pink,
    },
    bold = "#C1D1FF",
    string = string,
    number = number,
    ticket = "#fa89f6",
    datetime = "#FC824A",
    code = {
      inline = out.orange.desaturate(10).lighten(10),
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
      default = out.foreground.darken(20),
      active = out.cyan,
      done = out.common.comment,
      cancelled = "#fa4040",
      session = "#7378a5",
      schedule = "#FF8000",
    },
    tag = {
      hash = "#5BC0EB",
      positive = "#9BC53D",
      negative = "#FA4224",
      context = out.yellow,
      danger = { bg = "#C3423F", fg = "#ffffff" },
      identifier = "#e38fff",
    },
    list_item = {
      -- item = out.foreground.desaturate(20).darken(10),
      marker = out.foreground.desaturate(80).darken(40),
      label = out.yellow, -- "#c881de",
      label_marker = out.common.comment,
    },
    label = out.yellow,
  }

  out.rainbow = {
    red = out.red.darken(5).desaturate(30),
    yellow = out.yellow.darken(5).desaturate(30),
    blue = out.blue.darken(5).desaturate(30),
    orange = out.orange.darken(5).desaturate(30),
    green = out.green.darken(5).desaturate(30),
    violet = out.magenta.darken(5).desaturate(30),
    cyan = out.cyan.darken(5).desaturate(30),
  }

  out.ui = {
    surface0 = out.background.lighten(10),
    surface1 = out.background.lighten(20),
    surface2 = out.background.lighten(30),
    subtext0 = out.foreground.darken(10),
    subtext1 = out.foreground.darken(20),
    yellow = out.yellow,
    green = out.green,
    red = out.red,
  }
  return out
end

local dynamic = true

if dynamic then
  local base_hue = 260
  return gen(base_hue)
else
  local base_hue = 227
  local colors = {
    none = "NONE",
    background = hsl(base_hue, 15, 14),
    foreground = hsl(base_hue, 60, 85),
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
  local property = variable.darken(5).desaturate(20)
  local keyword = hsl(270, 50, 70)
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
    field = property.saturate(20).darken(5),
    parameter = colors.yellow,
    -- comment = colors.orange.desaturate(75).darken(35),
    comment = colors.orange.desaturate(60).darken(40),
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
end

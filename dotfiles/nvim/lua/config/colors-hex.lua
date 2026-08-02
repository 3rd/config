-- base colors
local colors = {
  background = "#202022",
  blue = "#31BBF8",
  common = {
    boolean = "#FF8170",
    builtin = "#EB806B",
    comment = "#82829B",
    conditional = "#F288E0",
    constant = "#FF8170",
    constructor = "#17CFCF",
    cword = "#3B3945",
    cword_current = "#403F43",
    delimiter = "#878792",
    field = "#BBBBCE",
    ["function"] = "#7EBDFC",
    identifier = "#DFDFEC",
    keyword = "#A7A7B4",
    macro = "#ACACF1",
    number = "#FF8170",
    operator = "#A7A7B4",
    parameter = "#E3AC63",
    property = "#BBBBCE",
    ["repeat"] = "#F288E0",
    ret = "#EB806B",
    special = "#FF80AA",
    special_keyword = "#FF80AA",
    string = "#ACD35F",
    type = "#17CFCF"
  },
  cyan = "#25DDD2",
  foreground = "#DEDEEC",
  green = "#6CDB4D",
  indigo = "#9B9AF9",
  magenta = "#CE70FF",
  none = "NONE",
  orange = "#FC8D5A",
  pink = "#E5A0FF",
  plugins = {
    indent_guides = {
      chunk = "#593D6B",
      indent = { "#3B3945" }
    }
  },
  red = "#FF5967",
  slang = {
    banner = {
      bg = "#38425B",
      fg = "#A9B9E5"
    },
    code = {
      block = {
        background = "#2C2A33",
        content = "#DFDFEC",
        language = "#6C687D",
        marker = "#3B3945"
      },
      inline = "#ED9145"
    },
    datetime = "#FC824A",
    document = {
      meta = "#82829B",
      meta_field = "#F075D1",
      meta_field_key = "#EC93D6",
      title = "#C0E774"
    },
    headline = {
      five = {
        bg = "#474B4D",
        fg = "#DFDFEC"
      },
      four = {
        bg = "#404345",
        fg = "#DFDFEC"
      },
      marker = "#A8A8C7",
      one = {
        bg = "#2B2B31",
        fg = "#DFDFEC"
      },
      six = {
        bg = "#4C5252",
        fg = "#DFDFEC"
      },
      three = {
        bg = "#333942",
        fg = "#DFDFEC"
      },
      two = {
        bg = "#30333B",
        fg = "#DFDFEC"
      }
    },
    label = "#E486CC",
    label_line = "#20C5C5",
    link = {
      external = "#6BABEB",
      internal = "#5BC0CD"
    },
    list_item = {
      label = "#A294EB",
      label_marker = "#82829B",
      marker = "#848490"
    },
    number = "#FF8170",
    outline = {
      five = "#04D2CE",
      four = "#FFC78F",
      one = "#9999FF",
      six = "#F0949D",
      three = "#E38FFF",
      two = "#BF8FFF"
    },
    section = "#8797C2",
    string = "#ACD35F",
    tag = {
      context = "#EDAF5E",
      danger = {
        bg = "#C3423F",
        fg = "#ffffff"
      },
      hash = "#5BC0EB",
      identifier = "#e38fff",
      negative = "#FA4224",
      positive = "#9BC53D"
    },
    task = {
      active = "#17CFCF",
      cancelled = "#fa4040",
      completion = "#7378a5",
      default = "#DFDFEC",
      done = "#616165",
      recurrence = "#7378a5",
      schedule = "#7378a5",
      session = "#7378a5"
    },
    ticket = "#fa89f6"
  },
  terminal = { "#2C2A33", "#FF5967", "#6CDB4D", "#F5B942", "#31BBF8", "#CE70FF", "#25DDD2", "#CAC8D0", "#6C687D", "#FF7A85", "#8CED71", "#FFD166", "#70D2FF", "#E5A0FF", "#65F5EA", "#F3F2F5" },
  ui = {
    breadcrumbs = {
      normal = {
        bg = "#323039",
        fg = "#AAAAC5"
      },
      separator = {
        fg = "#928F9F"
      }
    },
    line = {
      current_line = {
        bg = "#252528"
      },
      current_line_nr = {
        bg = "#3B3945",
        fg = "#6C687D"
      },
      current_line_sign = {
        bg = "#3B3945",
        fg = "#EB9147"
      },
      line_nr = {
        fg = "#3B3945"
      }
    },
    split = "#3B3945",
    status = {
      a = {
        bg = "#3B3945",
        fg = "#C4C4D9"
      },
      b = {
        bg = "#323039",
        fg = "#B7B7D1"
      },
      c = {
        bg = "#2C2A33",
        fg = "#AAAAC5"
      }
    },
    tabs = {
      active = {
        bg = "#323039",
        fg = "#DFDFEC",
        gui = "bold"
      },
      fill = {
        bg = "#202022",
        fg = "#7D7D97"
      },
      inactive = {
        bg = "#252528",
        fg = "#9292B0"
      }
    }
  },
  visual = "#323039",
  yellow = "#F5B942"
}

return colors
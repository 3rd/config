-- base colors
local colors = {
  background = "#222225",
  blue = "#31BBF8",
  common = {
    boolean = "#EEAF5D",
    builtin = "#E67A7F",
    comment = "#7B7B8A",
    conditional = "#F79065",
    constant = "#EEAF5D",
    constructor = "#5BD5E0",
    cword = "#3B3945",
    cword_current = "#403F43",
    delimiter = "#7E7E86",
    field = "#A9A9C1",
    ["function"] = "#67BBFF",
    identifier = "#CDCDD9",
    keyword = "#757589",
    macro = "#7B7BEA",
    number = "#EEAF5D",
    operator = "#757589",
    parameter = "#63E3C7",
    property = "#A9A9C1",
    ["repeat"] = "#F79065",
    ret = "#E67A7F",
    special = "#DE94D0",
    special_keyword = "#DE94D0",
    string = "#ACD35F",
    type = "#5BD5E0"
  },
  cyan = "#25DDD2",
  foreground = "#CDCDD9",
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
      bg = "#2D2E34",
      fg = "#5EE1ED"
    },
    code = {
      block = {
        background = "#2C2A33",
        content = "#CDCDD9",
        language = "#6C687D",
        marker = "#3B3945"
      },
      inline = "#FDC85E"
    },
    datetime = "#FC824A",
    document = {
      meta = "#7B7B8A",
      meta_field = "#F075D1",
      meta_field_key = "#EC93D6",
      title = "#1BDF83"
    },
    headline = {
      five = {
        bg = "#474B4D",
        fg = "#CDCDD9"
      },
      four = {
        bg = "#424548",
        fg = "#CDCDD9"
      },
      marker = "#9F9FB2",
      one = {
        bg = "#2D2E34",
        fg = "#CDCDD9"
      },
      six = {
        bg = "#4E5455",
        fg = "#CDCDD9"
      },
      three = {
        bg = "#353C45",
        fg = "#CDCDD9"
      },
      two = {
        bg = "#32353E",
        fg = "#CDCDD9"
      }
    },
    label = "#E486CC",
    label_line = "#63CFD9",
    link = {
      external = "#55A8EC",
      internal = "#5BC0CD"
    },
    list_item = {
      label = "#7DD6FC",
      label_marker = "#CDCDD9",
      marker = "#7C7C83"
    },
    number = "#EEAF5D",
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
      context = "#5EE1ED",
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
      active = "#5BD5E0",
      cancelled = "#fa4040",
      completion = "#7378a5",
      default = "#CDCDD9",
      done = "#646468",
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
        fg = "#A0A0B1"
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
        fg = "#FBAD4E"
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
    status_diagnostics = {
      hint = {
        fg = "#17CFCF"
      },
      info = {
        fg = "#7EBDFC"
      },
      warn = {
        fg = "#EB9147"
      }
    },
    tabs = {
      active = {
        bg = "#323039",
        fg = "#DFDFEC",
        gui = "bold"
      },
      fill = {
        bg = "#222225",
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
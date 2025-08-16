local hostname = vim.loop.os_gethostname()

-- base colors
local colors = {
  background = "#211F28",
  blue = "#83D3FC",
  common = {
    boolean = "#FF8170",
    builtin = "#EB806B",
    comment = "#716D88",
    conditional = "#F07AC9",
    constant = "#FF8170",
    constructor = "#17CFCF",
    cword = "#494659",
    delimiter = "#746F8B",
    field = "#A5A0BA",
    ["function"] = "#83D3FC",
    identifier = "#C6C3D5",
    keyword = "#9995B2",
    macro = "#AB9DF1",
    number = "#FF8170",
    operator = "#9995B2",
    parameter = "#EE9468",
    property = "#A5A0BA",
    ["repeat"] = "#F07AC9",
    ret = "#EB806B",
    special = "#FF85AD",
    special_keyword = "#FF85AD",
    string = "#C6EC79",
    type = "#17CFCF"
  },
  cyan = "#17CFCF",
  foreground = "#C6C3D5",
  green = "#C6EC79",
  indigo = "#9485E0",
  magenta = "#F075D1",
  none = "NONE",
  orange = "#EB9147",
  pink = "#EC93D6",
  plugins = {
    indent_guides = {
      chunk = "#9F3885",
      indent = { "#363442" }
    }
  },
  red = "#E02A06",
  slang = {
    banner = {
      bg = "#38425B",
      fg = "#A9B9E5"
    },
    code = {
      block = {
        background = "#282631",
        content = "#C6C3D5",
        language = "#5E5A72",
        marker = "#494659"
      },
      inline = "#ED9145"
    },
    datetime = "#FC824A",
    document = {
      meta = "#716D88",
      meta_field = "#F075D1",
      meta_field_key = "#EC93D6",
      title = "#D0ED97"
    },
    headline = {
      five = {
        bg = "#372528",
        fg = "#FF8FA2"
      },
      four = {
        bg = "#372531",
        fg = "#FF85D6"
      },
      marker = "#9B96B0",
      one = {
        bg = "#252837",
        fg = "#8FA2FF"
      },
      six = {
        bg = "#372B25",
        fg = "#FFB48F"
      },
      three = {
        bg = "#342537",
        fg = "#EC8FFF"
      },
      two = {
        bg = "#2B2537",
        fg = "#B48FFF"
      }
    },
    label = "#E486CC",
    label_line = "#20C5C5",
    link = {
      external = "#6FC2EB",
      internal = "#5BC0CD"
    },
    list_item = {
      label = "#A294EB",
      label_marker = "#716D88",
      marker = "#77767F"
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
    string = "#C6EC79",
    tag = {
      context = "#EDBE5E",
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
      default = "#C6C3D5",
      done = "#62606C",
      recurrence = "#7378a5",
      schedule = "#7378a5",
      session = "#7378a5"
    },
    ticket = "#fa89f6"
  },
  ui = {
    breadcrumbs = {
      normal = {
        bg = "#2F2D39",
        fg = "#9B97AF"
      },
      separator = {
        fg = "#87829B"
      }
    },
    line = {
      current_line = {
        bg = "#312F3C"
      },
      current_line_nr = {
        bg = "#363442",
        fg = "#89849F"
      },
      current_line_sign = {
        bg = "#363442",
        fg = "#EB9147"
      },
      line_nr = {
        fg = "#494659"
      }
    },
    split = "#2A2833",
    status = {
      a = {
        bg = "#3F3D4D",
        fg = "#B1AEC2"
      },
      b = {
        bg = "#363442",
        fg = "#A6A2B9"
      },
      c = {
        bg = "#2A2833",
        fg = "#9B97AF"
      }
    }
  },
  visual = "#A73CDD",
  yellow = "#EDBE5E"
}

-- host-specific overrides
if hostname == "death" then
-- colors.ui = {
--   breadcrumbs = {
--     normal = {
--       fg = "#A29CBF"
--     },
--     separator = {
--       fg = "#8D87AB"
--     }
--   },
--   line = {
--     current_line = {
--     },
--     current_line_nr = {
--       bg = "#3A3748",
--       fg = "#8D89A4"
--     },
--     current_line_sign = {
--       bg = "#3A3748",
--       fg = "#ED9A5E"
--     },
--     line_nr = {
--       fg = "#4F4B62"
--     }
--   },
--   split = "#312F3D",
--   status = {
--     a = {
--       bg = "#312F3D",
--       fg = "#BBB6D2"
--     },
--     b = {
--       bg = "#211F2D",
--       fg = "#ACA6C9"
--     },
--     c = {
--       bg = "#110F18",
--       fg = "#A29CBF"
--     }
--   }
-- }
end
return colors
local hostname = vim.loop.os_gethostname()

-- base colors
local colors = {
  background = "#23222B",
  blue = "#7EBDFC",
  common = {
    boolean = "#FF8170",
    builtin = "#EB806B",
    comment = "#7B7986",
    conditional = "#EF71C5",
    constant = "#FF8170",
    constructor = "#17CFCF",
    cword = "#383645",
    delimiter = "#777486",
    field = "#A5A0BA",
    ["function"] = "#7EBDFC",
    identifier = "#C8C6D2",
    keyword = "#9491A6",
    macro = "#A89AEF",
    number = "#FF8170",
    operator = "#9491A6",
    parameter = "#E3AC63",
    property = "#A5A0BA",
    ["repeat"] = "#EF71C5",
    ret = "#EB806B",
    special = "#FF80AA",
    special_keyword = "#FF80AA",
    string = "#ACD35F",
    type = "#17CFCF"
  },
  cyan = "#17CFCF",
  foreground = "#C8C6D2",
  green = "#ACD35F",
  indigo = "#9485E0",
  magenta = "#F075D1",
  none = "NONE",
  orange = "#EB9147",
  pink = "#EC93D6",
  plugins = {
    indent_guides = {
      chunk = "#9F3885",
      indent = { "#383645" }
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
        background = "#2A2833",
        content = "#C8C6D2",
        language = "#605C75",
        marker = "#4B485B"
      },
      inline = "#ED9145"
    },
    datetime = "#FC824A",
    document = {
      meta = "#7B7986",
      meta_field = "#F075D1",
      meta_field_key = "#EC93D6",
      title = "#C0E774"
    },
    headline = {
      five = {
        bg = "#434E56",
        fg = "#C8C6D2"
      },
      four = {
        bg = "#3F4650",
        fg = "#C8C6D2"
      },
      marker = "#9D9AAC",
      one = {
        bg = "#2D2B3B",
        fg = "#C8C6D2"
      },
      six = {
        bg = "#4A595E",
        fg = "#C8C6D2"
      },
      three = {
        bg = "#33394D",
        fg = "#C8C6D2"
      },
      two = {
        bg = "#313245",
        fg = "#C8C6D2"
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
      label_marker = "#7B7986",
      marker = "#79787D"
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
      default = "#C8C6D2",
      done = "#64626F",
      recurrence = "#7378a5",
      schedule = "#7378a5",
      session = "#7378a5"
    },
    ticket = "#fa89f6"
  },
  ui = {
    breadcrumbs = {
      normal = {
        bg = "#312F3C",
        fg = "#9E9CAB"
      },
      separator = {
        fg = "#8A8797"
      }
    },
    line = {
      current_line = {
        bg = "#2D2B36"
      },
      current_line_nr = {
        bg = "#383645",
        fg = "#8B87A1"
      },
      current_line_sign = {
        bg = "#383645",
        fg = "#EB9147"
      },
      line_nr = {
        fg = "#4B485B"
      }
    },
    split = "#2D2B36",
    status = {
      a = {
        bg = "#423F50",
        fg = "#B3B0BF"
      },
      b = {
        bg = "#383645",
        fg = "#A8A5B6"
      },
      c = {
        bg = "#2D2B36",
        fg = "#9E9CAB"
      }
    }
  },
  visual = "#471F5C",
  yellow = "#EDAF5E"
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
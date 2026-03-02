return lib.module.create({
  name = "misc/colorizer",
  hosts = "*",
  plugins = {
    {
      "catgoose/nvim-colorizer.lua",
      event = "BufReadPre",
      opts = {
        filetypes = { "*" },
        options = {
          parsers = {
            names = { enable = false },
            hex = {
              default = true,
              rgb = true,
              rgba = true,
              rrggbb = true,
              rrggbbaa = true,
              aarrggbb = true,
            },
            rgb = { enable = true },
            hsl = { enable = true },
            oklch = { enable = true },
            tailwind = {
              enable = true,
              update_names = true,
            },
            xterm = { enable = true },
          },
          display = {
            mode = "background",
            virtualtext = {
              char = "■",
              position = "eol",
              hl_mode = "foreground",
            },
          },
          always_update = false,
        },
      },
    },
  },
})

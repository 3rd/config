return lib.module.create({
  name = "misc/colorizer",
  hosts = "*",
  plugins = {
    {
      "catgoose/nvim-colorizer.lua",
      event = "BufReadPre",
      opts = {
        filetypes = { "*" },
        user_default_options = {
          names = false,
          RGB = true,
          RGBA = true,
          RRGGBB = true,
          RRGGBBAA = true,
          AARRGGBB = true,
          rgb_fn = true,
          hsl_fn = true,
          oklch_fn = true,
          tailwind = true,
          tailwind_opts = {
            update_names = true,
          },
          xterm = true,
          mode = "background",
          virtualtext = "■",
          virtualtext_inline = false,
          virtualtext_mode = "foreground",
          always_update = false,
        },
      },
    },
  },
})

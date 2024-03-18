local setup = function()
  local colorizer = require("colorizer")
  colorizer.setup({
    filetypes = { "*" },
    user_default_options = {
      mode = "background",
      names = false,
      rgb_fn = true,
      hsl_fn = true,
      RGB = true,
      RRGGBB = true,
      tailwind = true,
    },
    buftypes = {
      "*",
      "!prompt",
      "!popup",
    },
  })
end

return lib.module.create({
  name = "misc/colorizer",
  plugins = {
    {
      "NvChad/nvim-colorizer.lua",
      event = "VeryLazy",
      config = setup,
    },
  },
})

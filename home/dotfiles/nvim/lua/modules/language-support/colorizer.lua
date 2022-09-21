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

return require("lib").module.create({
  name = "language-support/colorizer",
  plugins = {
    { "NvChad/nvim-colorizer.lua", config = setup },
  },
})

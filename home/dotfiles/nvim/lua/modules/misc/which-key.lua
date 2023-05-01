local setup = function()
  require("which-key").setup({
    plugins = {
      marks = false,
      registers = false,
      spelling = { enabled = false },
      presets = {
        operators = false,
        motions = false,
        text_objects = false,
        windows = false,
        nav = false,
        z = false,
        g = true,
      },
    },
    window = {
      border = "single",
      position = "bottom",
      margin = { 1, 0, 1, 0 },
      padding = { 1, 1, 1, 1 },
      winblend = 0,
    },
    disable = {
      buftypes = {},
      filetypes = {},
    },
  })
end

return lib.module.create({
  name = "misc/which-key",
  plugins = {
    {
      "folke/which-key.nvim",
      event = "VeryLazy",
      config = setup,
    },
  },
})

local setup_autoclose = function()
  require("autoclose").setup({
    keys = {
      ["("] = { escape = false, close = true, pair = "()" },
      ["["] = { escape = false, close = true, pair = "[]" },
      ["{"] = { escape = false, close = true, pair = "{}" },

      [">"] = { escape = true, close = false, pair = "<>" },
      [")"] = { escape = true, close = false, pair = "()" },
      ["]"] = { escape = true, close = false, pair = "[]" },
      ["}"] = { escape = true, close = false, pair = "{}" },

      ['"'] = { escape = true, close = true, pair = '""' },
      ["`"] = { escape = true, close = true, pair = "``" },
      ["'"] = { escape = true, close = false, pair = "''" },
    },
    options = {
      disabled_filetypes = { "text", "syslang" },
      disable_when_touch = true,
    },
  })
end

return lib.module.create({
  enabled = false,
  hosts = { "spaceship", "macbook" },
  name = "workflow/auto-pair",
  plugins = {
    {
      "m4xshen/autoclose.nvim",
      event = "InsertEnter",
      config = setup_autoclose,
    },
  },
})

return lib.module.create({
  name = "language-support/languages/lua",
  plugins = {
    {
      "rafcamlet/nvim-luapad",
      cmd = { "Luapad", "LuaRun" },
    },
  },
})

return lib.module.create({
  name = "language-support/languages/lua",
  hosts = "*",
  plugins = {
    {
      "rafcamlet/nvim-luapad",
      cmd = { "Luapad", "LuaRun" },
    },
  },
})

return lib.module.create({
  name = "language-support/lua",
  plugins = {
    { "rafcamlet/nvim-luapad", cmd = { "Luapad", "LuaRun" } },
  },
})

local setup = function()
  local luasnip = require("luasnip")
  local lib = require("lib")

  luasnip.filetype_extend("all", { "_" })

  require("luasnip.loaders.from_snipmate").load({
    path = {
      lib.path.resolve(lib.env.dirs.config .. "/snippets"),
    },
  })
end

return require("lib").module.create({
  name = "completion/snippets",
  plugins = {
    { "L3MON4D3/LuaSnip", config = setup },
  },
})

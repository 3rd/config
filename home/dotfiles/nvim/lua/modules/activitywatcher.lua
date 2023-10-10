return lib.module.create({
  name = "activitywatcher",
  plugins = {
    {
      "ActivityWatch/aw-watcher-vim",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "aw-watcher-vim"),
      event = "VeryLazy",
      config = function()
        vim.api.nvim_command("AWStart")
      end,
    },
  },
})

return lib.module.create({
  name = "core/tracker",
  -- enabled = false,
  hosts = { "spaceship", "death" },
  plugins = {
    {
      "3rd/time-tracker.nvim",
      dependencies = {
        "3rd/sqlite.nvim",
      },
      dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "time-tracker.nvim"),
      event = "VeryLazy",
      opts = {
        data_file = vim.fn.stdpath("config") .. "/time-tracker.db",
      },
    },
  },
})

return lib.module.create({
  name = "tracker",
  enabled = false,
  hosts = { "spaceship", "macbook" },
  plugins = {
    {
      "3rd/time-tracker.nvim",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "time-tracker.nvim"),
      event = "VeryLazy",
      opts = {
        data_file = vim.fn.stdpath("config") .. "/time-tracker.json",
      },
    },
  },
})

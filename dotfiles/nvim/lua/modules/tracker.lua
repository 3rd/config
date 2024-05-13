return lib.module.create({
  name = "tracker",
  -- enabled = false,
  plugins = {
    {
      "3rd/time-tracker.nvim",
      event = "VeryLazy",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "time-tracker.nvim"),
      opts = {
        data_file = vim.fn.stdpath("config") .. "/time-tracker.json",
      },
    },
  },
})

return lib.module.create({
  name = "activitywatch",
  -- enabled = false,
  plugins = {
    {
      "3rd/aw-watcher-nvim",
      event = "VeryLazy",
      init = function()
        vim.g.aw_branch = true
      end,
      config = function()
        vim.api.nvim_command("AWStart")
      end,
    },
  },
})

return lib.module.create({
  name = "workflow/tmux",
  plugins = {
    {
      "tmux-plugins/vim-tmux",
      event = "VeryLazy",
      dependencies = {
        { "tmux-plugins/vim-tmux-focus-events" },
        { "christoomey/vim-tmux-navigator" },
      },
    },
  },
})

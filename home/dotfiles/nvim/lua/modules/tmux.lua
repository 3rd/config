return require("lib").module.create({
  name = "tmux",
  plugins = {
    { "tmux-plugins/vim-tmux" },
    { "tmux-plugins/vim-tmux-focus-events" },
    { "christoomey/vim-tmux-navigator" },
  },
})

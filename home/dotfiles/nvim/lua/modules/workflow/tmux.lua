return lib.module.create({
  name = "workflow/tmux",
  plugins = {
    {
      "tmux-plugins/vim-tmux",
      event = "VeryLazy",
      dependencies = {
        { "tmux-plugins/vim-tmux-focus-events" },
        -- { "christoomey/vim-tmux-navigator" },
        {
          "aserowy/tmux.nvim",
          opts = {
            copy_sync = {
              enable = false,
              ignore_buffers = { empty = false },
              redirect_to_clipboard = false,
              register_offset = 0,
              sync_clipboard = true,
              sync_registers = true,
              sync_deletes = true,
              sync_unnamed = true,
            },
            navigation = {
              cycle_navigation = true,
              enable_default_keybindings = true,
              persist_zoom = false,
            },
            resize = {
              enable_default_keybindings = false,
              resize_step_x = 4,
              resize_step_y = 4,
            },
          },
          keys = {
            { "<M-Left>", function() require("tmux").resize_left() end },
            { "<M-Right>", function() require("tmux").resize_right() end },
            { "<M-Up>", function() require("tmux").resize_top() end },
            { "<M-Down>", function() require("tmux").resize_bottom() end },
          },
        },
      },
    },
  },
})

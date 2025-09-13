return lib.module.create({
  name = "workflow/tmux",
  hosts = "*",
  plugins = {
    {
      "aserowy/tmux.nvim",
      config = function()
        require("tmux").setup({
          copy_sync = {
            enable = false,
            sync_clipboard = true,
            sync_registers = true,
            redirect_to_clipboard = false,
            register_offset = 0,
            sync_deletes = false,
          },
          navigation = {
            cycle_navigation = true,
            enable_default_keybindings = false,
            persist_zoom = false,
          },
          resize = {
            enable_default_keybindings = false,
            resize_step_x = 5,
            resize_step_y = 2,
          },
        })
      end,
      keys = {
        -- navigation
        { "<c-h>", "<cmd>lua require('tmux').move_left()<cr>", desc = "Navigate left" },
        { "<c-j>", "<cmd>lua require('tmux').move_bottom()<cr>", desc = "Navigate down" },
        { "<c-k>", "<cmd>lua require('tmux').move_top()<cr>", desc = "Navigate up" },
        { "<c-l>", "<cmd>lua require('tmux').move_right()<cr>", desc = "Navigate right" },
        -- resize
        { "<a-h>", "<cmd>lua require('tmux').resize_left()<cr>", desc = "Resize left" },
        { "<a-j>", "<cmd>lua require('tmux').resize_bottom()<cr>", desc = "Resize down" },
        { "<a-k>", "<cmd>lua require('tmux').resize_top()<cr>", desc = "Resize up" },
        { "<a-l>", "<cmd>lua require('tmux').resize_right()<cr>", desc = "Resize right" },
      },
    },
  },
})

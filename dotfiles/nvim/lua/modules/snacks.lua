return lib.module.create({
  name = "snacks",
  hosts = "*",
  plugins = {
    -- TODO: config + command menu
    -- https://github.com/folke/snacks.nvim?tab=readme-ov-file#-usage
    {
      "folke/snacks.nvim",
      priority = 1000,
      lazy = false,
      config = function()
        local snacks = require("snacks")
        snacks.setup({
          bigfile = { enabled = false },
          dashboard = { enabled = false },
          notifier = {
            enabled = true,
            timeout = 3000,
          },
          quickfile = { enabled = true },
          statuscolumn = { enabled = false },
          words = { enabled = false },
          styles = {
            notification = {
              wo = { wrap = true },
            },
          },
        })
      end,
      keys = {
        {
          "<leader>un",
          function()
            Snacks.notifier.hide()
          end,
          desc = "Dismiss All Notifications",
        },
        {
          "<leader>n",
          desc = "Notification history",
          function()
            Snacks.notifier.show_history()
          end,
        },
        {
          "<leader>N",
          desc = "Neovim News",
          function()
            Snacks.win({
              file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
              width = 0.6,
              height = 0.6,
              wo = {
                spell = false,
                wrap = false,
                signcolumn = "yes",
                statuscolumn = " ",
                conceallevel = 3,
              },
            })
          end,
        },
        {
          "<leader>gg",
          function()
            Snacks.lazygit()
          end,
        },
        {
          "<leader>gf",
          function()
            Snacks.lazygit.log_file()
          end,
        },
        {
          "<leader>ps",
          function()
            Snacks.profiler.scratch()
          end,
          desc = "Profiler Scratch Bufer",
        },
        {
          "<leader>pp",
          function()
            Snacks.profiler.toggle()
          end,
          desc = "Profiler Toggle",
        },
        {
          "<leader>ph",
          function()
            Snacks.profiler.toggle_highlights()
          end,
          desc = "Profiler Toggle Highlights",
        },
      },
    },
  },
})

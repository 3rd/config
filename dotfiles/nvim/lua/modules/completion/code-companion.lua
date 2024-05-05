return lib.module.create({
  name = "code-companion",
  enabled = false,
  plugins = {
    {
      "olimorris/codecompanion.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        "stevearc/dressing.nvim",
      },
      event = "VeryLazy",
      config = function()
        require("codecompanion").setup({
          adapters = {
            anthropic = require("codecompanion.adapters").use("anthropic"),
            openai = require("codecompanion.adapters").use("openai"),
          },
          send_code = true,
          silence_notifications = false, -- Silence notifications for actions like saving saving chats?
          use_default_actions = true, -- Use the default actions in the action palette?
          keymaps = {
            ["<cr>"] = "keymaps.save", -- Save the chat buffer and trigger the API
            ["q"] = "keymaps.close", -- Close the chat buffer
            ["<C-c>"] = "keymaps.cancel_request", -- Cancel the currently streaming request
            ["gc"] = "keymaps.clear", -- Clear the contents of the chat
            ["ga"] = "keymaps.codeblock", -- Insert a codeblock into the chat
            ["gs"] = "keymaps.save_chat", -- Save the current chat
            ["]"] = "keymaps.next", -- Move to the next header in the chat
            ["["] = "keymaps.previous", -- Move to the previous header in the chat
          },
        })

        vim.api.nvim_set_keymap("n", "<C-a>", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true })
        vim.api.nvim_set_keymap("v", "<C-a>", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true })
        vim.api.nvim_set_keymap("n", "<LocalLeader>a", "<cmd>CodeCompanionToggle<cr>", { noremap = true, silent = true })
        vim.api.nvim_set_keymap("v", "<LocalLeader>a", "<cmd>CodeCompanionToggle<cr>", { noremap = true, silent = true })
        vim.cmd([[cab cc CodeCompanion]])
      end,
    },
    {
      "folke/edgy.nvim",
      event = "VeryLazy",
      opts = {
        right = {
          { ft = "codecompanion", title = "Code Companion Chat", size = { width = 0.45 } },
        },
      },
    },
  },
  mappings = {
    { "n", "<leader>cc", ":CodeCompanion<CR>", "Code Companion" },
  },
})

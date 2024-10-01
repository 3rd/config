return lib.module.create({
  name = "workflow/outline",
  hosts = "*",
  plugins = {
    {
      "hedyhli/outline.nvim",
      cmd = { "Outline", "OutlineOpen", "OutlineFocus" },
      keys = {
        {
          "<leader>o",
          function()
            local outline = require("outline")
            if outline.is_open() then
              outline.focus_outline()
            else
              outline.open()
            end
          end,
          desc = "Toggle outline",
        },
      },
      opts = {
        outline_window = {
          auto_jump = true,
        },
        keymaps = {
          show_help = "?",
          close = { "<Esc>", "q" },
          goto_location = "<Cr>",
          peek_location = "o",
          goto_and_close = "<S-Cr>",
          restore_location = "<C-g>",
          hover_symbol = "<C-space>",
          toggle_preview = "K",
          rename_symbol = "<leader>er",
          code_actions = "<leader>ac",
          fold = "h",
          unfold = "l",
          fold_toggle = "<Tab>",
          fold_toggle_all = "<S-Tab>",
          fold_all = "zM",
          unfold_all = "zR",
          fold_reset = "zz",
          down_and_jump = "<C-j>",
          up_and_jump = "<C-k>",
        },
      },
    },
  },
})

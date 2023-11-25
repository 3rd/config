return lib.module.create({
  name = "language-support/comments",
  plugins = {
    {
      "numToStr/Comment.nvim",
      event = "VeryLazy",
      dependencies = { "JoosepAlviste/nvim-ts-context-commentstring" },
      config = function()
        require("Comment").setup({
          mappings = {
            basic = true,
            extra = true,
            extended = false,
          },
          pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
        })
      end,
    },
    {
      "folke/todo-comments.nvim",
      event = "VeryLazy",
      dependencies = { "nvim-lua/plenary.nvim" },
      opts = {
        signs = true,
        sign_priority = 8,
        keywords = {
          FIX = {
            icon = " ",
            color = "error",
            alt = { "FIXME", "BUG", "ISSUE" },
          },
          TODO = { icon = " ", color = "info", alt = { "REFACTOR" } },
          HACK = { icon = " ", color = "warning" },
          WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
          PERF = { icon = " ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
          NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
          TEST = { icon = " ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
        },
        gui_style = {
          fg = "NONE",
          bg = "BOLD",
        },
        merge_keywords = true,
        highlight = {
          multiline = true,
          multiline_pattern = "^.",
          multiline_context = 10,
          before = "", -- "fg" or "bg" or empty
          keyword = "wide", -- "fg", "bg", "wide", "wide_bg", "wide_fg" or empty
          after = "fg", -- "fg" or "bg" or empty
          pattern = [[.*<(KEYWORDS)\s*:]],
          comments_only = true,
          max_line_len = 400,
          exclude = {},
        },
        colors = {
          error = { "DiagnosticError", "ErrorMsg", "#DC2626" },
          warning = { "DiagnosticWarn", "WarningMsg", "#FBBF24" },
          info = { "DiagnosticInfo", "#2563EB" },
          hint = { "DiagnosticHint", "#10B981" },
          default = { "Identifier", "#7C3AED" },
          test = { "Identifier", "#FF00FF" },
        },
        search = {
          command = "rg",
          args = {
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
          },
          pattern = [[\b(KEYWORDS):]], -- or [[\b(KEYWORDS)\b]]
        },
      },
    },
    {
      "LudoPinelli/comment-box.nvim",
      opts = {
        doc_width = 80, -- width of the document
        box_width = 60, -- width of the boxes
        borders = { -- symbols used to draw a box
          top = "─",
          bottom = "─",
          left = "│",
          right = "│",
          top_left = "╭",
          top_right = "╮",
          bottom_left = "╰",
          bottom_right = "╯",
        },
        line_width = 70, -- width of the lines
        line = { -- symbols used to draw a line
          line = "─",
          line_start = "─",
          line_end = "─",
        },
        outer_blank_lines = true, -- insert a blank line above and below the box
        inner_blank_lines = false, -- insert a blank line above and below the text
        line_blank_line_above = false, -- insert a blank line above the line
        line_blank_line_below = false, -- insert a blank line below the line
      },
    },
  },
  mappings = {
    -- todo
    { "n", "<leader>t", "<cmd>TodoLocList<cr>", { desc = "Show TODOs" } },
  },
  actions = {
    -- comment box
    {
      "v",
      "Comment box (left-aligned)",
      function()
        vim.cmd("normal! gv")
        require("comment-box").lbox()
        vim.schedule(function()
          vim.api.nvim_exec("normal! \27", false)
        end)
      end,
    },
    {
      "v",
      "Comment box (centered)",
      function()
        vim.cmd("normal! gv")
        require("comment-box").ccbox()
        vim.schedule(function()
          vim.api.nvim_exec("normal! \27", false)
        end)
      end,
    },
  },
})

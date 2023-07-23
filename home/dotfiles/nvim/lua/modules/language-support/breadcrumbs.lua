local colors = require("config/colors-hex").ui

local config = {
  create_autocmd = false,
  attach_navic = false,
  exclude_filetypes = {
    "astro",
    "fzf",
    "gitcommit",
    "syslang",
    "terminal",
  },
  symbols = {
    modified = "●",
    ellipsis = "…",
    separator = "❯",
  },
  theme = {
    normal = { bg = colors.surface1, fg = colors.subtext0 },
    separator = { fg = colors.subtext1 },
  },
}

return lib.module.create({
  enabled = false,
  name = "language-support/breadcrumbs",
  plugins = {
    {
      "utilyre/barbecue.nvim",
      event = "VimEnter",
      dependencies = {
        "SmiteshP/nvim-navic",
        "nvim-tree/nvim-web-devicons",
      },
      config = function()
        require("barbecue").setup(config)

        vim.api.nvim_create_autocmd({
          "WinScrolled",
          "BufWinEnter",
          "CursorHold",
          "InsertLeave",
          "BufWritePost",
          "TextChanged",
          "TextChangedI",
        }, {
          group = vim.api.nvim_create_augroup("barbecue.updater", {}),
          callback = function()
            require("barbecue.ui").update()
          end,
        })
      end,
    },
  },
  hooks = {
    lsp = {
      on_attach_call = function(client, bufnr)
        local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
        if vim.tbl_contains(config.exclude_filetypes, ft) then return end
        if client.server_capabilities.documentSymbolProvider then require("nvim-navic").attach(client, bufnr) end
      end,
    },
  },
})

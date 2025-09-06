local colors = require("config/colors-hex")

local barbecue_config = {
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
    ellipsis = "…",
    modified = "●",
    separator = "❯",
  },
  theme = {
    normal = colors.ui.breadcrumbs.normal,
    separator = colors.ui.breadcrumbs.separator,
  },
}

return lib.module.create({
  name = "language-support/breadcrumbs",
  enabled = false,
  hosts = "*",
  hooks = {
    lsp = {
      on_attach_call = function(client, bufnr)
        local ft = vim.bo.filetype
        if vim.tbl_contains(barbecue_config.exclude_filetypes, ft) then return end
        if client.server_capabilities.documentSymbolProvider then require("nvim-navic").attach(client, bufnr) end
      end,
    },
  },
  plugins = {
    {
      "utilyre/barbecue.nvim",
      event = "VeryLazy",
      dependencies = {
        "SmiteshP/nvim-navic",
        "nvim-tree/nvim-web-devicons",
      },
      config = function()
        require("barbecue").setup(barbecue_config)

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
})

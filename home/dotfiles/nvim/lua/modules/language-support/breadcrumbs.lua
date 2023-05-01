local exclude_filetypes = {
  "gitcommit",
  "toggleterm",
  "syslang",
  "astro",
}

local setup_barbecue = function()
  require("barbecue").setup({
    create_autocmd = false,
    attach_navic = false,
    exclude_filetypes = exclude_filetypes,
    symbols = {
      modified = "●",
      ellipsis = "…",
      separator = "❯",
    },
    theme = {
      normal = { bg = "#404152" },
      separator = { fg = "#70738f" },
    },
  })

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
end

return lib.module.create({
  name = "language-support/breadcrumbs",
  plugins = {
    {
      "utilyre/barbecue.nvim",
      lazy = false,
      -- event = "VeryLazy",
      dependencies = {
        "SmiteshP/nvim-navic",
        "nvim-tree/nvim-web-devicons",
      },
      config = setup_barbecue,
    },
  },
  hooks = {
    lsp = {
      on_attach_call = function(client, bufnr)
        local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
        if vim.tbl_contains(exclude_filetypes, ft) then return end
        if client.server_capabilities.documentSymbolProvider then require("nvim-navic").attach(client, bufnr) end
      end,
    },
  },
})

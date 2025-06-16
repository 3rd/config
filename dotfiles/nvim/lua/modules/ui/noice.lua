local setup_noice = function()
  require("noice").setup({
    cmdline = {
      enabled = false,
    },
    messages = { enabled = false },
    popupmenu = { enabled = false },
    notify = { enabled = false },
    lsp = {
      progress = { enabled = false },
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
      hover = {
        enabled = true,
        silent = true,
      },
      signature = { enabled = false },
      message = { enabled = false },
    },
    markdown = {
      hover = {
        ["|(%S-)|"] = vim.cmd.help, -- vim help links
        ["%[.-%]%((%S-)%)"] = require("noice.util").open, -- markdown links
      },
      highlights = {
        ["|%S-|"] = "@text.reference",
        ["@%S+"] = "@parameter",
        ["^%s*(Parameters:)"] = "@text.title",
        ["^%s*(Return:)"] = "@text.title",
        ["^%s*(See also:)"] = "@text.title",
        ["{%S-}"] = "@parameter",
        ["%[.-%]%((%S-)%)"] = "@macro",
      },
    },
    views = {
      views = {
        cmdline_input = {
          enter = true,
        },
      },
      -- hover = {
      --   -- https://github.com/folke/noice.nvim/blob/main/lua/noice/config/preset.lua#L55
      --   border = {
      --     padding = { 0, 1 },
      --   },
      --   position = { row = 2, col = 2 },
      -- },
    },
  })
end

return lib.module.create({
  name = "ui/noice",
  hosts = "*",
  -- enabled = false,
  plugins = {
    {
      "folke/noice.nvim",
      event = "VeryLazy",
      dependencies = {
        { "MunifTanjim/nui.nvim" },
      },
      config = setup_noice,
    },
  },
})

local setup = function()
  vim.defer_fn(function()
    local env = require("lib.env")
    require("copilot").setup({
      plugin_manager_path = env.dirs.packer_pack,
      panel = {
        enabled = true,
        auto_refresh = false,
        keymap = {
          jump_prev = "[[",
          jump_next = "]]",
          accept = "<CR>",
          refresh = "gr",
          open = "<M-CR>",
        },
      },
      suggestion = {
        enabled = true,
        auto_trigger = true,
        debounce = 75,
        keymap = {
          -- accept = "<tab>",
          next = "<c-right>",
          prev = "<c-left>",
          dismiss = "<C-]>",
        },
      },
      filetypes = {
        ["*"] = false,
        lua = true,
        nix = true,
        go = true,
        rust = true,
        sh = true,
        typescript = true,
        typescriptreact = true,
        javascript = true,
        javascriptreact = true,
        html = true,
        vue = true,
        css = true,
        scss = true,
        astro = true,
        mdx = true,
      },
      server_opts_overrides = {
        settings = {
          advanced = {
            listCount = 10, -- #completions for panel
            inlineSuggestCount = 4, -- #completions for getCompletions
          },
        },
      },
    })
  end, 1000)
end

return require("lib").module.create({
  enabled = false,
  name = "completion/copilot",
  plugins = {
    -- { "github/copilot.vim" },
    { "zbirenbaum/copilot.lua", config = setup },
  },
})

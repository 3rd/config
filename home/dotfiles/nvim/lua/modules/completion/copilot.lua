local setup = function()
  -- https://github.com/fauxpilot/fauxpilot/discussions/72
  -- https://github.com/nzlov/cmp-fauxpilot
  -- vim.g.copilot_proxy = "http://localhost:5000"

  require("copilot").setup({
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
      debounce = 300,
      keymap = {
        accept = "<c-l>",
        next = "<c-right>",
        prev = "<c-left>",
        dismiss = "<c-]>",
      },
    },
    filetypes = {
      -- "*" = false,
      sh = function()
        if string.match(vim.fs.basename(vim.api.nvim_buf_get_name(0)), "^%.env.*") then return false end
        return true
      end,
      syslang = false,
    },
    -- https://github.com/zbirenbaum/copilot.lua/blob/master/SettingsOpts.md
    server_opts_overrides = {
      trace = "verbose",
      settings = {
        advanced = {
          listCount = 10, -- panel
          inlineSuggestCount = 3, -- getCompletions
          length = 1000,
          top_p = 1,
          temperature = 0,
          debug = {
            githubCTSIntegrationEnabled = false,
          },
        },
      },
    },
  })
end

return lib.module.create({
  enabled = false,
  name = "completion/copilot",
  plugins = {
    -- { "github/copilot.vim" },
    {
      "zbirenbaum/copilot.lua",
      event = { "InsertEnter" },
      config = setup,
    },
  },
})

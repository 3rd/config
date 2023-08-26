-- https://github.com/fauxpilot/fauxpilot/discussions/72
-- https://github.com/nzlov/cmp-fauxpilot
-- vim.g.copilot_proxy = "http://localhost:5000"

local config = {
  panel = {
    enabled = true,
    auto_refresh = true,
    keymap = {
      open = "<M-CR>",
      accept = "<CR>",
      refresh = "gr",
      jump_next = "]]",
      jump_prev = "[[",
    },
  },
  suggestion = {
    enabled = true,
    auto_trigger = true,
    debounce = 75,
    keymap = {
      accept = "<c-l>",
      next = "<c-right>",
      prev = "<c-left>",
    },
  },
  filetypes = {
    -- "*" = false,
    cvs = false,
    gitcommit = false,
    gitrebase = false,
    help = false,
    markdown = false,
    syslang = false,
    sh = function()
      if string.match(vim.fs.basename(vim.api.nvim_buf_get_name(0)), "^%.env.*") then return false end
      return true
    end,
  },
  -- https://github.com/zbirenbaum/copilot.lua/blob/master/SettingsOpts.md
  server_opts_overrides = {
    trace = "verbose",
    settings = {
      editor = {
        delayCompletions = 0,
        formatOnType = false,
      },
      advanced = {
        listCount = 5,
        inlineSuggestCount = 5,
        length = 1000,
        top_p = 1,
        temperature = 0,
        debug = {
          githubCTSIntegrationEnabled = false,
          showScores = "",
          useSuffix = "",
          -- overrideProxyUrl = "",
          -- testOverrideProxyUrl = "",
          -- overrideEngine = "",
          -- overrideLogLevels = "",
          -- filterLogCategories = "",
          -- acceptSelfSignedCertificate = "",
        },
      },
    },
  },
}

return lib.module.create({
  enabled = false,
  name = "completion/copilot",
  plugins = {
    -- { "github/copilot.vim" },
    {
      "zbirenbaum/copilot.lua",
      event = { "InsertEnter", "LspAttach" },
      opts = config,
    },
  },
  mappings = {
    { "n", "<leader>p", "<cmd>lua require('copilot.panel').open()<cr>" },
  },
})

local is_initialized = false

local config = {
  keymaps = {
    accept_suggestion = "<C-l>",
    clear_suggestion = "<C-]>",
  },
  ignore_filetypes = {
    dotenv = true,
    syslang = true,
    markdown = true,
    help = true,
    gitcommit = true,
    gitrebase = true,
    gitstatus = true,
    yaml = true,
    toml = true,
    json = true,
    text = true,
  },
  color = {
    suggestion_color = "#ffffff",
    cterm = 244, -- "#ffffff",
  },
}

return lib.module.create({
  name = "completion/supermaven",
  enabled = false,
  hosts = { "spaceship", "macbook" },
  plugins = {
    {
      "supermaven-inc/supermaven-nvim",
      commit = "df3ecf7",
      -- "Hashiraee/supermaven-nvim",
      event = "VeryLazy",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "supermaven-nvim"),
    },
  },
  actions = {
    {
      "n",
      "SuperMaven: Start",
      function()
        if not is_initialized then
          is_initialized = true
          require("supermaven-nvim").setup(config)
          return
        end
        require("supermaven-nvim.api").start()
      end,
    },
    {
      "n",
      "SuperMaven: Stop",
      function()
        require("supermaven-nvim.api").stop()
      end,
    },
    {
      "n",
      "SuperMaven: Show logs",
      function()
        require("supermaven-nvim.api").show_log()
      end,
    },
  },
})

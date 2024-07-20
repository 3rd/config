local config = {
  enabled = false,
  autostart = true,
  opts = {
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
  },
}

local is_initialized = false

return lib.module.create({
  name = "completion/supermaven",
  enabled = config.enabled,
  hosts = { "spaceship", "macbook" },
  plugins = {
    {
      "supermaven-inc/supermaven-nvim",
      event = "VeryLazy",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "supermaven-nvim"),
      config = function()
        if not config.autostart then return end
        require("supermaven-nvim").setup(config.opts)
      end,
    },
  },
  actions = {
    {
      "n",
      "SuperMaven: Start",
      function()
        if not is_initialized then
          is_initialized = true
          require("supermaven-nvim").setup(config.opts)
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

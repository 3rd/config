local config = {
  enabled = false,
  autostart = false,
  opts = {
    keymaps = {
      accept_suggestion = "<C-l>",
      clear_suggestion = "<C-]>",
    },
    ignore_filetypes = {
      dotenv = true,
      gitcommit = true,
      gitrebase = true,
      gitstatus = true,
      help = true,
      json = true,
      syslang = true,
      text = true,
      toml = true,
      yaml = true,
    },
    color = {
      cterm = 244, -- "#ffffff",
      suggestion_color = "#ffffff",
    },
  },
}

local is_initialized = false

local is_running = function()
  return package.loaded["supermaven-nvim"] ~= nil and require("supermaven-nvim.api").is_running()
end

local is_stopped = function()
  return not is_running()
end

return lib.module.create({
  name = "completion/supermaven",
  enabled = config.enabled,
  hosts = { "spaceship", "macbook", "death" },
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
      is_stopped,
    },
    {
      "n",
      "SuperMaven: Stop",
      function()
        require("supermaven-nvim.api").stop()
      end,
      is_running,
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

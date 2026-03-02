local env = require("lib/env")

local lazy_plugin_path = env.dirs.vim.lazy.plugin

local install = function()
  if not vim.uv.fs_stat(lazy_plugin_path) then
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable",
      lazy_plugin_path,
    })
  end
end

local setup = function(plugins, config)
  require("lazy").setup(plugins, config)
end

return {
  install = install,
  setup = setup,
}

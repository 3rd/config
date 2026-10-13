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

local function configure_command_plugins(plugins)
  local commands = require("lib/commands")
  local spec = require("lazy.core.plugin").Spec
  local result = {}
  for _, plugin in ipairs(plugins) do
    local definition = type(plugin) == "string" and { plugin } or vim.tbl_extend("force", {}, plugin)
    if definition.dependencies then definition.dependencies = configure_command_plugins(definition.dependencies) end

    local source = definition[1] or definition.url or definition.dir
    local name = definition.name
    if not name then
      if definition[1] and not definition[1]:find("/", 1, true) then
        name = definition[1]
      elseif source then
        name = spec.get_name(source)
      end
    end

    if name and commands.has_plugin_commands(name) then
      local configure = definition.config
      definition.config = function(loaded_plugin, opts)
        if type(configure) == "function" then
          configure(loaded_plugin, opts)
        elseif configure or loaded_plugin.opts then
          local main = require("lazy.core.loader").get_main(loaded_plugin)
          assert(main, "Command plugin has no setup module: " .. loaded_plugin.name)
          require(main).setup(opts)
        end

        commands.initialize_plugin(loaded_plugin.name)
      end
    end

    table.insert(result, definition)
  end

  return result
end

local setup = function(plugins, config)
  require("lazy").setup(configure_command_plugins(plugins), config)
end

return {
  install = install,
  setup = setup,
}

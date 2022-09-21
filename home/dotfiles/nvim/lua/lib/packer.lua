local env = require("lib/env")
local path = require("lib/path")
local random = require("lib/random")

local package_site_path = string.format("%s/.packer", vim.fn.stdpath("config"))
local package_root_path = string.format("%s/pack", package_site_path)
local compile_path = string.format("%s/compiled.lua", package_site_path)
local packer_path = string.format("%s/packer/start/packer.nvim", package_root_path)

local module = {
  repo = { frozen = false, plugins = {} },
  wrapped_handlers = {},
}

local wrap = function(fn)
  local hash = random.string()
  if module.wrapped_handlers[hash] ~= nil then
    throw("Wrapped plugin handler collision: ", hash)
  end
  module.wrapped_handlers[hash] = fn
  return 'require("lib/packer").wrapped_handlers["' .. hash .. '"]()'
end

module.init = function()
  if vim.fn.empty(vim.fn.glob(packer_path)) > 0 then
    vim.fn.execute("!git clone https://github.com/wbthomason/packer.nvim " .. packer_path)
  end
  vim.opt.packpath = package_site_path
  if not env.is_dev and path.is_readable_file(compile_path) then
    vim.cmd(string.format("luafile %s", compile_path))
  end
end

module.register_plugin = function(plugin)
  if module.repo.frozen then
    throw("Error: Cannot register plugin when repository is frozen.")
  end
  table.insert(module.repo.plugins, plugin)
end

module.load = function()
  local packer = require("packer")
  module.repo.frozen = true

  packer.init({
    -- log = { level = "trace" },
    plugin_package = "packer",
    compile_path = compile_path,
    package_root = package_root_path,
    ensure_dependencies = true,
    max_jobs = nil,
    auto_clean = true,
    compile_on_sync = true,
    disable_commands = false,
    opt_default = false,
    transitive_opt = true,
    transitive_disable = true,
    auto_reload_compiled = true,
    profile = {
      enable = false,
      threshold = 1,
    },
    autoremove = false,
  })

  -- packer.startup(function()
  packer.reset()
  packer.use({ "wbthomason/packer.nvim" })
  for _, plugin in ipairs(module.repo.plugins) do
    if env.is_dev and plugin.config then
      plugin.config = wrap(plugin.config)
    end
    packer.use(plugin)
  end
  -- end)

  if env.is_dev then
    packer.compile()
  end
end

return module

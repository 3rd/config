require("lib")

-- create directories
local directories = {
  lib.env.dirs.vim.backup,
  lib.env.dirs.vim.sessions,
  lib.env.dirs.vim.undo,
  lib.env.dirs.vim.view,
}
for _, dir in ipairs(directories) do
  if not lib.fs.directory.exists(dir) then
    local ok = lib.fs.directory.create(dir)
    if not ok then throw("Could not create directory: " .. dir) end
  end
end

-- disable crap
-- vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- options
local options = require("config/options")
for k, v in pairs(options) do
  vim.opt[k] = v
end

-- https://github.com/neovim/neovim/issues/29047
vim.api.nvim_create_autocmd("UIEnter", {
  pattern = "*",
  callback = function()
    vim.defer_fn(function()
      vim.opt.ttimeout = false
    end, 2000)
  end,
})

-- filetype
vim.filetype.add(require("config/filetype"))

-- modules
local modules = lib.module.get_enabled_modules()
for _, module in ipairs(modules) do
  if module.setup then module:setup() end
end

-- mappings
local mappings = require("config/mappings")
vim.g.mapleader = mappings.leader
vim.g.maplocalleader = mappings.localleader
for _, mapping in ipairs(mappings.default) do
  local mode, lhs, rhs, opts_or_desc = mapping[1], mapping[2], mapping[3], mapping[4]
  local opts =
    table.merge(mappings.defaultOptions, lib.is.string(opts_or_desc) and { desc = opts_or_desc } or opts_or_desc or {})
  lib.map.map(mode, lhs, rhs, opts)
end
for _, module in ipairs(modules) do
  if module.mappings then
    for _, mapping in ipairs(module.mappings) do
      local mode, lhs, rhs, opts_or_desc = mapping[1], mapping[2], mapping[3], mapping[4]
      local opts = table.merge(
        mappings.defaultOptions,
        lib.is.string(opts_or_desc) and { desc = opts_or_desc } or opts_or_desc or {}
      )
      lib.map.map(mode, lhs, rhs, opts)
    end
  end
end

-- plugins
local plugins = table.join(
  lib.module.get_module_plugins(),
  table.map({
    { dir = "tslib", lazy = false },
    { dir = "testing.nvim" },
    { dir = "sqlite.nvim" },
  }, function(item)
    item.dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", item.dir)
    return item
  end)
)

local profile_on_startup = false
if profile_on_startup then
  vim.api.nvim_create_autocmd("User", {
    pattern = { "LazyDone" },
    callback = function()
      vim.schedule(function()
        -- vim.cmd([[sleep 3000m]])
        vim.cmd([[Lazy profile]])
      end)
    end,
  })
end

-- lazy
lib.lazy.install()
vim.opt.rtp:prepend(lib.env.dirs.vim.lazy.plugin)
lib.lazy.setup(plugins, require("config/lazy"))
-- package.path = package.path .. ";" .. vim.fn.expand("$HOME") .. "/.luarocks/share/lua/5.1/?/init.lua;"
-- package.path = package.path .. ";" .. vim.fn.expand("$HOME") .. "/.luarocks/share/lua/5.1/?.lua;"

local is = require("lib/is")
local packer = require("lib/packer")

local Module = {
  __is_module = true,
  enabled = true,
  debug = false,
  name = "",
  plugins = {},
  extends = {},
  setup = nil,
  hooks = {
    capabilities = nil,
    lsp_on_attach = nil,
  },
  mappings = nil,
  actions = nil,
  export = {},
}

function Module:new(props)
  local instance = {
    debug = props.debug,
    name = props.name,
    plugins = props.plugins or {},
    extends = props.extends or {},
    setup = props.setup or Module.setup,
    hooks = props.hooks or Module.hooks,
    mappings = props.mappings or Module.mappings,
    actions = props.actions or Module.actions,
    export = props.export or Module.export,
  }
  setmetatable(instance, self)
  self.__index = self
  if is.bool(props.enabled) then instance.enabled = props.enabled end
  return instance
end

function Module:log(message)
  if self.debug then print(string.format("[%s] %s", self.name, message)) end
end

function Module:load()
  if not self.enabled then
    self:log(string.format("Skipping module %s because it is disabled.", self.name))
    return
  end
  self:log(string.format("Loading module: %s", self.name))
  if self.plugins then
    for _, plugin in ipairs(self.plugins) do
      packer.register_plugin(plugin)
    end
  end
  if self.setup then
    self:log(string.format("Running module setup: %s", self.name))
    self:setup()
  end
end

local get_modules = function()
  local lua_dir = string.format("%s/lua", vim.fn.stdpath("config"))
  local modules_dir = string.format("%s/modules", lua_dir)
  local paths = vim.split(vim.fn.glob(string.format("%s/**/*.lua", modules_dir)), "\n")
  local result = {}
  for _, path in ipairs(paths) do
    path = string.gsub(path, string.format("%s/", string.gsub(lua_dir, "%-", "%%-")), "")
    path = string.gsub(path, ".lua$", "")
    local module = require(path)
    if module.__is_module then table.insert(result, module) end
  end
  return result
end

local get_enabled_modules = function()
  local modules = get_modules()
  local result = {}
  for _, module in ipairs(modules) do
    if module.enabled then table.insert(result, module) end
  end
  return result
end

return {
  get_modules = get_modules,
  get_enabled_modules = get_enabled_modules,
  create = function(props) return Module:new(props) end,
  load_modules = function()
    local modules = get_modules()
    for _, module in ipairs(modules) do
      module:load()
    end
  end,
}

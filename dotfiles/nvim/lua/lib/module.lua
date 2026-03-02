local is = require("lib/is")

---@class lsp_hooks
---@field capabilities nil|fun(capabilities: table): table|nil
---@field on_attach nil|fun(client: table, bufnr: number)

---@class hooks
---@field lsp lsp_hooks|nil
---@field treesitter string[]|nil
---@field lspconfig table<string, lsp_hooks>|nil
---@field null table<any>|nil
---@field mason string[]|nil

---@class Module
---@field name string
---@field enabled boolean|nil
---@field hosts string[] | "*"
---@field debug boolean|nil
---@field plugins LazyPluginSpec[]|nil
---@field setup function|nil
---@field hooks hooks|nil
---@field mappings ({ [1]: MappingMode|MappingMode[], [2]: string, [3]: string|function, [4]: string|table })[]|nil
---@field actions ({ [1]: string, [2]: string, [3]: string|function})[]|nil
---@field exports table<string, any>|nil
local Module = {
  __is_module = true,
  name = "",
  enabled = true,
  hosts = {},
  debug = true,
  plugins = {},
  setup = nil,
  hooks = nil,
  mappings = nil,
  actions = nil,
  exports = {},
}

---@param props Module
---@return Module
function Module:new(props)
  props = props or {}

  local instance = setmetatable({
    enabled = props.enabled == nil and self.enabled or props.enabled,
    hosts = props.hosts or self.hosts,
    debug = props.debug == nil and self.debug or props.debug,
    name = props.name or self.name,
    plugins = props.plugins or self.plugins,
    setup = props.setup or self.setup,
    hooks = props.hooks or self.hooks,
    mappings = props.mappings or self.mappings,
    actions = props.actions or self.actions,
    exports = props.exports or self.exports,
  }, { __index = self })

  return instance
end

function Module:log(...)
  if self.debug then log(string.format("[%s]", self.name, ...)) end
end

---@param opts? { exclude: string[] }
---@return Module[]
local get_modules = function(opts)
  opts = opts or {}
  local lua_dir = string.format("%s/lua", vim.fn.stdpath("config"))
  local modules_dir = string.format("%s/modules", lua_dir)
  local paths = vim.split(vim.fn.glob(string.format("%s/**/*.lua", modules_dir)), "\n", {})

  local hostname = vim.uv.os_gethostname()

  if is.table(opts.exclude) then
    for _, exclude in ipairs(opts.exclude) do
      paths = vim.tbl_filter(function(path)
        return not string.find(path, exclude)
      end, paths)
    end
  end

  local result = {}
  for _, path in ipairs(paths) do
    path = string.gsub(path, string.format("%s/", string.gsub(lua_dir, "%-", "%%-")), "")
    path = string.gsub(path, ".lua$", "")
    if is.no.empty(path) then
      local ok, module = pcall(require, path)
      if not ok then error(string.format("Error loading module %s: %s", path, module)) end
      ---@cast module Module
      local is_module = ok and type(module) == "table" and module.__is_module
      local is_valid_module_for_host = is_module
        and (
          module.hosts == "*"
          ---@diagnostic disable-next-line: param-type-mismatch
          or (type(module.hosts) == "table" and vim.tbl_contains(module.hosts, hostname))
        )
      if is_valid_module_for_host then table.insert(result, module) end
    end
  end
  return result
end

---@param opts? { exclude?: string[] }
---@return Module[]
local get_enabled_modules = function(opts)
  local modules = get_modules(opts)
  local result = {}
  for _, module in ipairs(modules) do
    if module.enabled then table.insert(result, module) end
  end
  return result
end

---@param modules_override? Module[]
---@return Module[]
local get_module_plugins = function(modules_override)
  local modules = modules_override or get_modules()
  local plugins = {}
  for _, module in ipairs(modules) do
    if module.enabled then
      for _, plugin in ipairs(module.plugins) do
        table.insert(plugins, plugin)
      end
    end
  end
  return plugins
end

---@param props Module
local create_module = function(props)
  return Module:new(props)
end

return {
  create = create_module,
  get_modules = get_modules,
  get_enabled_modules = get_enabled_modules,
  get_module_plugins = get_module_plugins,
}

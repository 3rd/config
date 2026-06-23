require("lib/installer/types")

local INSTALLER_DIR = vim.fs.joinpath(vim.fn.stdpath("data"), "installer")

---@type table<string, InstallerTool>
local tools = {
  ["cssmodules-language-server"] = {
    kind = "npm",
    package = "cssmodules-language-server",
    version = "1.5.2",
    bin = "cssmodules-language-server",
    lspconfig = "cssmodules_ls",
  },
  ["vscode-langservers-extracted"] = {
    kind = "npm",
    package = "vscode-langservers-extracted",
    version = "4.10.0",
    bin = "vscode-json-language-server",
    lspconfig = "jsonls",
  },
  fixjson = {
    kind = "npm",
    package = "fixjson",
    version = "1.1.2",
    bin = "fixjson",
  },
  rustywind = {
    kind = "npm",
    package = "rustywind",
    version = "0.24.3",
    bin = "rustywind",
    allow_scripts = true,
  },
}

---@return string[]
local get_tool_names = function()
  local result = vim.tbl_keys(tools)
  table.sort(result)
  return result
end

---@param name string
---@return InstallerTool|nil
local get_tool = function(name)
  return tools[name]
end

---@param bin string
---@return string|nil name
---@return InstallerTool|nil tool
local get_by_bin = function(bin)
  for _, name in ipairs(get_tool_names()) do
    local tool = tools[name]
    if tool.bin == bin then return name, tool end
  end
  return nil, nil
end

---@param name string
---@return string
local get_install_dir = function(name)
  return vim.fs.joinpath(INSTALLER_DIR, name)
end

---@param name string
---@return string|nil
local get_bin_dir = function(name)
  local tool = get_tool(name)
  if not tool then return nil end
  if tool.kind == "npm" then return vim.fs.joinpath(get_install_dir(name), "node_modules", ".bin") end
  return nil
end

---@param name string
---@return string|nil
local get_executable_path = function(name)
  local tool = get_tool(name)
  local dir = get_bin_dir(name)
  if not tool or not dir then return nil end
  return vim.fs.joinpath(dir, tool.bin)
end

---@param name string
---@return boolean
local is_installed = function(name)
  local path = get_executable_path(name)
  return path ~= nil and vim.fn.executable(path) == 1
end

---@type InstallerRegistry
local registry = {
  root = INSTALLER_DIR,
  tools = tools,
  names = get_tool_names,
  get = get_tool,
  get_by_bin = get_by_bin,
  get_install_dir = get_install_dir,
  get_bin_dir = get_bin_dir,
  get_executable_path = get_executable_path,
  is_installed = is_installed,
}

return registry

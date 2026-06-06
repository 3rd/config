local registry = require("lib/installer/registry")

local PATH_SEPARATOR = vim.fn.has("win32") == 1 and ";" or ":"

local path_has_dir = function(dir)
  for _, path in ipairs(vim.split(vim.env.PATH or "", PATH_SEPARATOR, { plain = true, trimempty = true })) do
    if path == dir then return true end
  end
  return false
end

local path_update_prepend = function(dir)
  if not dir or vim.fn.isdirectory(dir) == 0 or path_has_dir(dir) then return end
  vim.env.PATH = dir .. PATH_SEPARATOR .. (vim.env.PATH or "")
end

local resolve_from_path = function(bin)
  local path = vim.fn.exepath(bin)
  if path == "" then return nil end
  return path
end

local resolve_from_registry = function(name, tool)
  local installed = registry.get_executable_path(name)
  if installed and vim.fn.executable(installed) == 1 then return installed end
  return resolve_from_path(tool.bin)
end

local resolve = function(name_or_bin)
  local tool = registry.get(name_or_bin)
  if tool then return resolve_from_registry(name_or_bin, tool) end

  local name, by_bin = registry.get_by_bin(name_or_bin)
  if by_bin then return resolve_from_registry(name, by_bin) end

  return resolve_from_path(name_or_bin)
end

local state = function(name)
  if registry.is_installed(name) then return "installed" end

  local tool = registry.get(name)
  if tool and resolve_from_path(tool.bin) then return "path" end

  return "missing"
end

local prepend_installed_bins = function()
  for _, name in ipairs(registry.names()) do
    if registry.is_installed(name) then path_update_prepend(registry.get_bin_dir(name)) end
  end
end

local status_lines = function()
  local lines = {}
  for _, name in ipairs(registry.names()) do
    local tool = registry.get(name)
    table.insert(lines, ("%s [%s]"):format(name, state(name)))
    table.insert(lines, ("  kind: %s"):format(tool.kind))
    table.insert(lines, ("  pin: %s@%s"):format(tool.package, tool.version))
    table.insert(lines, ("  resolved: %s"):format(resolve(name) or "n/a"))
    table.insert(lines, ("  install: %s"):format(registry.get_install_dir(name)))
  end
  return lines
end

local install_npm = function(name, tool)
  if vim.fn.executable("npm") == 0 then error("npm is not executable") end

  if registry.is_installed(name) then
    path_update_prepend(registry.get_bin_dir(name))
    return
  end

  local install_dir = registry.get_install_dir(name)
  if vim.fn.mkdir(install_dir, "p") == 0 and vim.fn.isdirectory(install_dir) == 0 then
    error("could not create install directory: " .. install_dir)
  end

  local output = vim.fn.system({
    "npm",
    "install",
    "--prefix",
    install_dir,
    "--ignore-scripts",
    "--no-audit",
    "--no-fund",
    "--package-lock=false",
    "--save-exact",
    "--omit=dev",
    ("%s@%s"):format(tool.package, tool.version),
  })
  if vim.v.shell_error ~= 0 then error(output) end
  if not registry.is_installed(name) then error("install completed but executable is missing: " .. tool.bin) end
  path_update_prepend(registry.get_bin_dir(name))
end

local install = function(name)
  local tool = registry.get(name)
  if not tool then error("unknown installer tool: " .. name) end

  if tool.kind == "npm" then
    install_npm(name, tool)
  else
    error("unsupported installer kind: " .. tostring(tool.kind))
  end

  if tool.lspconfig then pcall(vim.lsp.enable, tool.lspconfig) end
  vim.notify(("installed: %s"):format(name), vim.log.levels.INFO)
end

local sync_configured = function()
  for _, name in ipairs(registry.names()) do
    install(name)
  end
end

return {
  registry = registry,
  install = install,
  names = registry.names,
  prepend_installed_bins = prepend_installed_bins,
  resolve = resolve,
  state = state,
  status_lines = status_lines,
  sync_configured = sync_configured,
}

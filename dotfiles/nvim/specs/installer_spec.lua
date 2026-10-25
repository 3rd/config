require("lib")

local installer = require("lib/installer")
local registry = installer.registry
local root = vim.fn.tempname()

local tools = {
  typescript = { kind = "npm", package = "typescript", version = "7.0.0", bin = "tsc" },
  ["vscode-langservers-extracted"] = {
    kind = "npm",
    package = "vscode-langservers-extracted",
    version = "4.0.0",
    bin = "vscode-json-language-server",
  },
}

local get_bin_dir = function(name)
  return vim.fs.joinpath(root, name, "node_modules", ".bin")
end

local create_executable = function(path)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ "#!/bin/sh" }, path)
  vim.uv.fs_chmod(path, 493)
end

create_executable(vim.fs.joinpath(get_bin_dir("typescript"), "tsc"))
create_executable(vim.fs.joinpath(get_bin_dir("vscode-langservers-extracted"), "vscode-json-language-server"))
create_executable(vim.fs.joinpath(get_bin_dir("vscode-langservers-extracted"), "vscode-css-language-server"))
create_executable(vim.fs.joinpath(get_bin_dir("vscode-langservers-extracted"), "tsc"))

registry.names = function()
  local names = vim.tbl_keys(tools)
  table.sort(names)
  return names
end
registry.get = function(name)
  return tools[name]
end
registry.get_install_dir = function(name)
  return vim.fs.joinpath(root, name)
end
registry.get_bin_dir = get_bin_dir
registry.get_executable_path = function(name)
  return vim.fs.joinpath(get_bin_dir(name), tools[name].bin)
end
registry.is_installed = function(name)
  return vim.fn.executable(registry.get_executable_path(name)) == 1
end

vim.env.PATH = "/usr/bin:/bin"
installer.prepend_installed_bins()

assert(vim.fn.exepath("tsc") == registry.get_executable_path("typescript"), "a dependency's tsc must not shadow it")
assert(vim.fn.exepath("vscode-json-language-server") == registry.get_executable_path("vscode-langservers-extracted"))
assert(
  vim.fn.exepath("vscode-css-language-server")
    == vim.fs.joinpath(get_bin_dir("vscode-langservers-extracted"), "vscode-css-language-server"),
  "a tool's other bins must stay on PATH"
)

tools.tsserver = { kind = "npm", package = "typescript", version = "6.0.0", bin = "tsserver" }
local fake_npm_dir = vim.fs.joinpath(root, "fake-npm")
create_executable(vim.fs.joinpath(fake_npm_dir, "npm"))
vim.fn.system = function(...)
  create_executable(vim.fs.joinpath(get_bin_dir("tsserver"), "tsc"))
  create_executable(vim.fs.joinpath(get_bin_dir("tsserver"), "tsserver"))
  return ""
end
vim.notify = function() end

vim.env.PATH = fake_npm_dir .. ":" .. vim.env.PATH
installer.install("tsserver")

assert(vim.fn.exepath("tsc") == registry.get_executable_path("typescript"), "a fresh install's tsc must not shadow it")
assert(vim.fn.exepath("tsserver") == registry.get_executable_path("tsserver"))

vim.fn.delete(root, "rf")
print("ok: installer puts each installed tool's own bin ahead of other tools' dependency bins, also after an install")

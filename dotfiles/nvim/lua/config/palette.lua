local config_home = vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.env.HOME, ".config")
local installed_path = vim.fs.joinpath(config_home, "theme", "colors.json")
local config_path = vim.uv.fs_realpath(vim.fn.stdpath("config"))

if not config_path then error("Could not resolve the Neovim configuration path") end

local loader_path = vim.fs.joinpath(config_path, "..", "theme", "palette.lua")
local palette_loader = dofile(loader_path)
local repository_path = vim.fs.joinpath(config_path, "..", "..", "home-manager", "colors.nix")
local palette = palette_loader.load_nix(repository_path)
if palette then return palette end

palette = palette_loader.load_json(installed_path, vim.json.decode)
if palette then return palette end

error(string.format("Could not find theme palette at %s or in the configuration repository", installed_path))

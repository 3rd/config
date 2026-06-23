---@alias InstallerToolKind "npm"

---@class InstallerTool
---@field kind InstallerToolKind
---@field package string
---@field version string
---@field bin string
---@field allow_scripts boolean|nil
---@field lspconfig string|nil

---@class InstallerRegistry
---@field root string
---@field tools table<string, InstallerTool>
---@field names fun(): string[]
---@field get fun(name: string): InstallerTool|nil
---@field get_by_bin fun(bin: string): string|nil, InstallerTool|nil
---@field get_install_dir fun(name: string): string
---@field get_bin_dir fun(name: string): string|nil
---@field get_executable_path fun(name: string): string|nil
---@field is_installed fun(name: string): boolean

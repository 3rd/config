local dotnet_version_cache_path = vim.fn.stdpath("cache") .. "/dotnet-version-cache.json"

---@return nil|table
local read_dotnet_version_cache = function()
  if vim.fn.filereadable(dotnet_version_cache_path) == 0 then return nil end
  local ok, lines = pcall(vim.fn.readfile, dotnet_version_cache_path)
  if not ok or not lines or #lines == 0 then return nil end
  local ok_decode, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_decode or type(data) ~= "table" then return nil end
  return data
end

---@param data table
local write_dotnet_version_cache = function(data)
  pcall(vim.fn.writefile, { vim.json.encode(data) }, dotnet_version_cache_path)
end

---@return nil|number
local get_dotnet_major_version = function()
  local dotnet_path = vim.fn.exepath("dotnet")
  if dotnet_path == "" then return nil end

  local stat = vim.uv.fs_stat(dotnet_path)
  local key = table.concat({
    dotnet_path,
    tostring((stat and stat.size) or 0),
    tostring((stat and stat.mtime and stat.mtime.sec) or 0),
  }, ":")

  local cached = read_dotnet_version_cache()
  if cached and cached.key == key and type(cached.major) == "number" then return cached.major end

  local version = vim.trim(vim.fn.system({ dotnet_path, "--version" }))
  if vim.v.shell_error ~= 0 then return nil end

  local major = tonumber(version:match("^(%d+)"))
  if major then
    write_dotnet_version_cache({
      key = key,
      major = major,
    })
  end
  return major
end

return lib.module.create({
  name = "language-support/mason",
  -- enabled = false,
  hosts = "*",
  plugins = {
    {
      "mason-org/mason.nvim",
      lazy = false,
      dependencies = {
        "mason-org/mason-lspconfig.nvim",
      },
      config = function()
        local mason = require("mason")
        local mason_lspconfig = require("mason-lspconfig")
        local servers = require("config/lsp-servers")
        local installable_servers = servers
        local ensure_installed = servers

        local dotnet_major = nil
        if vim.tbl_contains(servers, "csharp_ls") then
          dotnet_major = get_dotnet_major_version()
        end

        local compatible_versions = {}
        if dotnet_major and dotnet_major < 10 then
          -- csharp-ls >=0.17 targets net9+/net10 and fails to install with dotnet 8.
          compatible_versions.csharp_ls = "0.16.0"
        end

        local has_server_mappings, server_mappings = pcall(require, "mason-lspconfig.mappings.server")
        if has_server_mappings and server_mappings.lspconfig_to_package then
          installable_servers = vim.tbl_filter(function(server)
            local has_package = server_mappings.lspconfig_to_package[server] ~= nil
            if not has_package then return false end
            if server == "csharp_ls" and not dotnet_major then return false end
            return true
          end, servers)
        end

        ensure_installed = vim.tbl_map(function(server)
          local version = compatible_versions[server]
          if version then return string.format("%s@%s", server, version) end
          return server
        end, installable_servers)

        mason.setup()

        local setup_mason_lspconfig = function()
          mason_lspconfig.setup({
            automatic_enable = false,
            ensure_installed = ensure_installed,
          })
        end

        if vim.g.did_very_lazy then
          setup_mason_lspconfig()
        else
          vim.api.nvim_create_autocmd("User", {
            pattern = "VeryLazy",
            once = true,
            callback = setup_mason_lspconfig,
          })
        end
      end,
    },
  },
})

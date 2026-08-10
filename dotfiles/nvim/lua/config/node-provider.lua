local node_host = lib.path.resolve(
  lib.env.dirs.vim.config,
  "plugins",
  "tslib",
  "rplugin",
  "node",
  "tslib",
  "node_modules",
  "neovim",
  "bin",
  "cli.js"
)

local setup = function()
  vim.g.node_host_prog = node_host
end

return {
  host = node_host,
  setup = setup,
}

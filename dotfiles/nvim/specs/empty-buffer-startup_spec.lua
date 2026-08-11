require("lib")

local original_find_root = lib.path.find_root
lib.path.find_root = function()
  error("LSP module inspected the current directory while defining plugins")
end
package.loaded["modules/language-support/lspconfig"] = nil
local lsp = require("modules/language-support/lspconfig")
lib.path.find_root = original_find_root

local eslint = lsp.plugins[5]
assert(vim.deep_equal(eslint.event, { "BufReadPre", "BufNewFile" }), "ESLint does not defer setup until a file opens")

local branch_lookups = 0
local git_branch = {
  find_git_dir = function()
    branch_lookups = branch_lookups + 1
    return "/tmp/.git"
  end,
}
local lualine_config = nil

package.loaded["lualine"] = nil
package.loaded["lualine.components.branch.git_branch"] = nil
package.preload["lualine"] = function()
  return {
    setup = function(config)
      lualine_config = config
    end,
  }
end
package.preload["lualine.components.branch.git_branch"] = function()
  return git_branch
end

package.loaded["modules/ui/statusline"] = nil
require("modules/ui/statusline").plugins[1].config()

assert(lualine_config ~= nil, "statusline setup did not run")
git_branch.find_git_dir()
assert(branch_lookups == 0, "statusline inspected the current directory for an empty buffer")

vim.api.nvim_buf_set_name(0, "/tmp/empty-buffer-startup.lua")
git_branch.find_git_dir()
assert(branch_lookups == 1, "statusline did not enable branch lookup for a file buffer")

print("ok: empty-buffer startup defers plugin metadata reads")

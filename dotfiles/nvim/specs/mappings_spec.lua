local root = vim.fn.tempname()
vim.env.XDG_CACHE_HOME = root .. "/cache"
vim.env.XDG_STATE_HOME = root .. "/state"
require("lib")

local callback = function() end
local mappings = {
  leader = " ",
  localleader = ",",
  defaultOptions = { silent = true },
  default = {
    { "n", "<leader>a", ":echo 'global'<CR>", "Global mapping" },
    { "n", "<leader>b", callback, { silent = false, nowait = true, desc = "Callback mapping" } },
    { "n", "<leader>c", ":echo 'default'<CR>" },
  },
  lsp = {
    { "n", "K", callback, "LSP hover" },
    { "n", "gd", callback, { buffer = false, silent = true, desc = "LSP definition" } },
  },
}
local modules = {
  { mappings = { { "n", "<leader>a", ":echo 'first'<CR>", "First module" } } },
  { mappings = { { "n", "<leader>a", ":echo 'second'<CR>", "Second module" } } },
  {},
}
local original_mappings = vim.deepcopy(mappings)
local original_modules = vim.deepcopy(modules)
package.loaded["config/mappings"] = mappings
lib.module.get_enabled_modules = function()
  return modules
end
lib.module.get_module_plugins = function()
  return {}
end
lib.lazy.install = function() end
lib.lazy.setup = function() end
require("config")

local overridden = vim.fn.maparg(" a", "n", false, true)
assert(overridden.rhs == ":echo 'second'<CR>" and overridden.desc == "Second module")
assert(overridden.silent == 1 and overridden.buffer == 0, "module mappings must inherit global defaults")
local explicit = vim.fn.maparg(" b", "n", false, true)
assert(explicit.callback == callback and explicit.silent == 0 and explicit.nowait == 1)
assert(vim.fn.maparg(" c", "n", false, true).silent == 1, "mappings without options must inherit defaults")
assert(vim.g.mapleader == " " and vim.g.maplocalleader == ",")

package.loaded["blink.cmp"] = {
  get_lsp_capabilities = function(capabilities)
    return capabilities
  end,
}
lib.module.get_enabled_modules = function()
  return {}
end
dofile("after/plugin/lsp.lua")

local attached_buf = vim.api.nvim_create_buf(true, false)
local other_buf = vim.api.nvim_get_current_buf()
vim.api.nvim_exec_autocmds("LspAttach", { buffer = attached_buf, data = {} })
vim.api.nvim_buf_call(attached_buf, function()
  local hover = vim.fn.maparg("K", "n", false, true)
  assert(hover.callback == callback and hover.buffer == 1 and hover.silent == 0)
  local definition = vim.fn.maparg("gd", "n", false, true)
  assert(definition.buffer == 1 and definition.silent == 1, "LSP buffer scope must override mapping options")
end)
assert(#vim.api.nvim_buf_get_keymap(other_buf, "n") == 0, "LSP mappings must stay on the attached buffer")

vim.keymap.set("n", "K", ":echo 'custom'<CR>", { buffer = attached_buf })
vim.api.nvim_exec_autocmds("LspAttach", { buffer = attached_buf, data = {} })
vim.api.nvim_buf_call(attached_buf, function()
  assert(vim.fn.maparg("K", "n", false, true).rhs == ":echo 'custom'<CR>", "a second attach must keep buffer mappings")
end)
assert(vim.deep_equal(mappings, original_mappings) and vim.deep_equal(modules, original_modules))

vim.api.nvim_del_augroup_by_name("command-toggles")
vim.api.nvim_create_autocmd("VimLeave", {
  callback = function()
    vim.fn.delete(root, "rf")
  end,
})
print("ok: startup and LSP mappings preserve defaults, overrides, callbacks, order, and buffer ownership")

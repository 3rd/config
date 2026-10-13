require("lib")

local config
package.loaded.conform = {
  setup = function(options)
    config = options
  end,
}
require("modules/language-support/formatting").plugins[1].config()
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local cwd = vim.fn.getcwd()
vim.fn.chdir(root)
local buffer = vim.api.nvim_create_buf(false, true)
vim.bo[buffer].filetype = "typescript"

local options, on_format = config.format_on_save(buffer)
assert(
  vim.deep_equal(options, { timeout_ms = 2000, lsp_fallback = "always", formatters = { "prettierd", "rustywind" } })
)
assert(config.format_after_save(buffer) == nil)
on_format("formatter failed")
assert(config.format_on_save(buffer) ~= nil, "ordinary errors must retain synchronous formatting")

vim.fn.writefile({}, root .. "/.noformat")
options, on_format = config.format_on_save(buffer)
assert(vim.deep_equal(options.formatters, { "rustywind" }), ".noformat must filter only prettier")
assert(vim.deep_equal(config.formatters_by_ft.typescript, { "prettierd", "rustywind" }))
on_format("formatter timeout")
assert(config.format_on_save(buffer) == nil)
local after_save = config.format_after_save(buffer)
assert(vim.deep_equal(after_save, { lsp_fallback = "always", formatters = { "rustywind" } }))

local other_buffer = vim.api.nvim_create_buf(false, true)
vim.bo[other_buffer].filetype = "typescript"
assert(config.format_on_save(other_buffer) == nil, "timeout policy is shared by filetype")
vim.bo[other_buffer].filetype = "lua"
local lua_options = config.format_on_save(other_buffer)
assert(vim.deep_equal(lua_options, { timeout_ms = 2000, lsp_fallback = true, formatters = { "stylua" } }))
vim.bo[other_buffer].filetype = "text"
assert(config.format_on_save(other_buffer).formatters == nil)

vim.fn.delete(root .. "/.noformat")
assert(vim.deep_equal(config.format_after_save(buffer).formatters, { "prettierd", "rustywind" }))
vim.fn.chdir(cwd)
vim.fn.delete(root, "rf")
print("ok: formatting preserves formatter order, opt-out, LSP policy, and timeout-driven after-save routing")

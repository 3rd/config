require("lib")

vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/nvim-colorizer.lua")
vim.opt.termguicolors = true

local bufnr = vim.api.nvim_get_current_buf()
local plugin = require("modules/misc/colorizer").plugins[1]
local colorizer = require("colorizer")

colorizer.setup(plugin.opts)
vim.bo[bufnr].filetype = "css"
assert(colorizer.is_buffer_attached(bufnr), "Colorizer did not attach to the configured filetype")

local defer_fn = vim.defer_fn
local deferred = {}
vim.defer_fn = function(callback, timeout)
  local timer = { stopped = false }
  timer.stop = function(self)
    self.stopped = true
  end
  deferred[#deferred + 1] = { callback = callback, timeout = timeout, timer = timer }
  return timer
end

vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "color: #fff;" })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = bufnr })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = bufnr })

assert(#deferred == 2, "Colorizer did not schedule both changed-buffer requests")
assert(deferred[1].timeout > 0 and deferred[2].timeout > 0, "Colorizer updates were not debounced")
assert(deferred[1].timer.stopped, "Colorizer did not cancel the stale update")
assert(not deferred[2].timer.stopped, "Colorizer canceled the latest update")

vim.defer_fn = defer_fn
deferred[2].callback()

print("ok: Colorizer debounces insert updates")

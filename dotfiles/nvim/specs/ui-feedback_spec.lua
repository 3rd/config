require("lib")

local options = require("config/options")
vim.o.showcmd = options.showcmd
vim.o.shortmess = options.shortmess
assert(not vim.o.showcmd and vim.o.shortmess:find("S", 1, true), "native command-line counters must be hidden")

for _, plugin in ipairs({ "lualine.nvim", "nvim-web-devicons" }) do
  vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end
require("modules/ui/statusline").plugins[1].config()
local config = require("lualine").get_config()
local components = config.sections.lualine_x
local recording = components[1]
local maximize = components[2]
local progress = components[3]
assert(recording() == "")
vim.api.nvim_feedkeys("qq", "nx", false)
assert(recording() == "REC @q")
vim.api.nvim_feedkeys("q", "nx", false)
assert(recording() == "")
vim.t.maximized = true
assert(maximize() == "ZOOM")
vim.t.maximized = false
assert(maximize() == "")
assert(progress[1] == "lsp_status" and not progress.show_name and progress.symbols.done == "")

local get_clients = vim.lsp.get_clients
vim.lsp.get_clients = function()
  return { { id = 991, name = "test" } }
end
local has_progress = function()
  local text = vim.api.nvim_eval_statusline(vim.o.statusline, {}).str
  return text:find("\226\160", 1, true) ~= nil
end
vim.api.nvim_exec_autocmds("LspProgress", {
  data = { client_id = 991, params = { value = { kind = "begin", title = "Indexing" } } },
})
require("lualine").refresh({ force = true })
assert(vim.wait(1000, has_progress), "active statusline must display LSP progress")
vim.api.nvim_exec_autocmds("LspProgress", {
  data = { client_id = 991, params = { value = { kind = "end" } } },
})
require("lualine").refresh({ force = true })
assert(
  vim.wait(1000, function()
    return not has_progress()
  end),
  "idle LSP must not add statusline clutter"
)
vim.lsp.get_clients = get_clients

local selection = config.sections.lualine_z[2]
assert(not selection.cond())
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "match match", "other" })
vim.api.nvim_feedkeys("ggVj", "nx", false)
assert(selection.cond())
assert(selection.fmt(require("lualine.components.selectioncount")()) == "SEL 2")
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
assert(not selection.cond())

local delivered
package.loaded.notify = setmetatable({ setup = function() end }, {
  __call = function(_, message, level, opts)
    delivered = { message = message, level = level, opts = opts }
  end,
})
require("modules/ui/notifications").plugins[1].config()
for _, case in ipairs({
  { level = vim.log.levels.INFO, timeout = 2000 },
  { level = vim.log.levels.WARN, timeout = 6000 },
  { level = vim.log.levels.ERROR, timeout = 10000 },
}) do
  vim.notify("Exact message", case.level)
  assert(delivered.message == "Exact message" and delivered.level == case.level)
  assert(delivered.opts.timeout == case.timeout)
end
vim.notify("Persistent error", vim.log.levels.ERROR, { timeout = false })
assert(delivered.opts.timeout == false, "explicit notification duration must be preserved")
print("ok: contextual status components and severity-aware notification durations")

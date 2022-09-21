local syntax = require("syslang/syntax")
local folding = require("syslang/folding")

local setup_options = function()
  vim.opt.commentstring = "-- %s"
  vim.opt.fillchars = "fold: "
  vim.opt.foldlevelstart = 999
  vim.opt.textwidth = 0
  vim.opt.wrap = true
  vim.opt.signcolumn = "yes:1"
  vim.opt.number = false
  vim.opt.breakindent = true
  vim.opt.breakindentopt = "list:2" -- TODO move to list:-1 with formatlistpat
  vim.opt.formatlistpat = "^\\s*[\\[-]"
end

local handle_toggle_task = function()
  local view = vim.fn.winsaveview()
  local line = vim.fn.getline(".")
  if vim.fn.match(line, "\\v\\[\\s\\]") >= 0 then -- [ ] -> [-]
    vim.api.nvim_exec("s/\\v\\[\\zs\\s\\ze\\]/-/g", true)
  elseif vim.fn.match(line, "\\v\\[-\\]") >= 0 then -- [-] -> [x]
    vim.api.nvim_exec("s/\\v\\[\\zs-\\ze\\]/x/g", true)
  elseif vim.fn.match(line, "\\v\\[(✔|x|X)\\]") >= 0 then -- [x] -> [ ]
    vim.api.nvim_exec("s/\\v\\[\\zs(✔|x|X)\\ze\\]/ /g", true)
  else
    vim.api.nvim_exec("s/\\v\\zs\\S\\ze/[ ] \\0/g", true) -- .* -> [ ] \0
  end
  vim.cmd("nohl")
  vim.fn.winrestview(view)
end

local handle_expand_all = function()
  vim.opt.foldlevel = 999
  require("ufo").openAllFolds()
  vim.cmd("w")
end
local handle_collapse_all = function()
  vim.opt.foldlevel = 999
  require("ufo").openAllFolds()
  vim.cmd("w")
  require("ufo").closeAllFolds()
end

local setup = function()
  -- if not vim.b.slang_loaded then
  --   return
  -- end
  -- vim.b.slang_loaded = true

  setup_options()
  syntax.register()
  folding.register()

  -- mappings
  vim.keymap.set("n", "<c-space>", handle_toggle_task, { buffer = true })
  vim.keymap.set("n", "zR", handle_expand_all, { buffer = true })
  vim.keymap.set("n", "zM", handle_collapse_all, { buffer = true })
end

return {
  setup = setup,
}

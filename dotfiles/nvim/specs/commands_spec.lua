local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.env.XDG_STATE_HOME = root .. "/state"

local commands = require("lib/commands")
local state_dir = vim.fn.stdpath("state") .. "/command-toggles"
local is_enabled = true
local toggle = {
  kind = "toggle",
  id = "test.feature",
  name = "test feature",
  persist = true,
  is_enabled = function()
    return is_enabled
  end,
  set_enabled = function(should_enable)
    is_enabled = should_enable
  end,
}
local modules = { { actions = { toggle } } }
commands.setup(modules)
assert(is_enabled, "missing preferences must preserve the provider default")
assert(vim.uv.fs_stat(state_dir) == nil, "restoration must not write default preferences")
commands.get_actions("n")["Disable test feature"]()
assert(vim.json.decode(vim.fn.readfile(state_dir .. "/test.feature.json")[1]) == false)

local child_path = root .. "/restart.lua"
vim.fn.writefile({
  'local commands = require("lib/commands")',
  "local is_enabled = true",
  "local feature = {",
  '  kind = "toggle", id = "test.feature", name = "renamed label", persist = false,',
  "  is_enabled = function() return is_enabled end,",
  "  set_enabled = function(should_enable) is_enabled = should_enable end,",
  "}",
  "local modules = { { actions = { feature } } }",
  "commands.setup(modules)",
  'assert(is_enabled, "a nonpersistent feature must use its default in a new process")',
  "feature.persist = true",
  "commands.setup(modules)",
  'assert(is_enabled == false, "a new process must restore false by stable ID")',
  "is_enabled = true",
  'vim.cmd("qall!")',
}, child_path)
local result = vim
  .system({
    vim.v.progpath,
    "-n",
    "-i",
    "NONE",
    "--headless",
    "--clean",
    "--cmd",
    "set runtimepath^=" .. vim.fn.fnameescape(vim.fn.getcwd()),
    "-l",
    child_path,
  }, { text = true })
  :wait()
assert(result.code == 0, result.stderr)
assert(
  vim.json.decode(vim.fn.readfile(state_dir .. "/test.feature.json")[1]) == true,
  "normal exit must save state changed outside the menu"
)
vim.api.nvim_exec_autocmds("VimLeavePre", {})
assert(
  vim.json.decode(vim.fn.readfile(state_dir .. "/test.feature.json")[1]) == true,
  "an unchanged older instance must not overwrite a newer preference"
)
commands.setup(modules)
assert(is_enabled, "saved true must restore over the current false state")

toggle.persist = false
is_enabled = false
commands.setup(modules)
assert(not is_enabled, "persist=false must ignore previously saved state")
commands.get_actions("n")["Enable test feature"]()
commands.get_actions("n")["Disable test feature"]()
vim.api.nvim_exec_autocmds("VimLeavePre", {})
assert(
  vim.json.decode(vim.fn.readfile(state_dir .. "/test.feature.json")[1]) == true,
  "persist=false must leave saved preferences unchanged"
)

local warnings = {}
vim.notify = function(message, level)
  assert(level == vim.log.levels.WARN)
  table.insert(warnings, message)
end
toggle.persist = true
vim.fn.writefile({ '{"enabled":true}' }, state_dir .. "/test.feature.json")
commands.setup(modules)
assert(not is_enabled and #warnings == 1, "invalid persisted shapes must warn and keep the default")

toggle.set_enabled = function()
  error("setter failed")
end
local did_set, set_error = pcall(commands.get_actions("n")["Enable test feature"])
assert(not did_set and set_error:find("setter failed"), "setter errors must propagate")
assert(
  vim.fn.readfile(state_dir .. "/test.feature.json")[1] == '{"enabled":true}',
  "a failed setter must not save the requested value"
)
toggle.set_enabled = function(should_enable)
  is_enabled = should_enable
end
vim.fn.delete(state_dir .. "/test.feature.json")
vim.fn.mkdir(state_dir .. "/test.feature.json")
commands.get_actions("n")["Enable test feature"]()
assert(is_enabled and #warnings == 2, "failed saves must warn without reverting the runtime state")
assert(#vim.fn.glob(state_dir .. "/*.tmp", false, true) == 0, "failed saves must clean up temporary files")

vim.api.nvim_del_augroup_by_name("command-toggles")
vim.fn.delete(root, "rf")
print("ok: toggle persistence survives processes, respects opt-out, and handles invalid state and write failures")

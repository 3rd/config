require("lib")

local state_root = vim.fn.tempname()
vim.env.XDG_STATE_HOME = state_root
vim.env.XDG_CACHE_HOME = state_root .. "/cache"
vim.opt.runtimepath:prepend(lib.env.dirs.vim.lazy.plugin)
local git_module = require("modules/workflow/git")
local did_run_action = false
local ordinary_module = lib.module.create({
  actions = {
    {
      kind = "action",
      group = "Test",
      name = "ordinary action",
      run = function()
        did_run_action = true
      end,
    },
    {
      "n",
      "Test: hidden action",
      function()
        error("hidden action ran")
      end,
      function()
        return false
      end,
    },
    { "v", "Test: visual action", "let g:command_menu_visual = 1" },
  },
})

local selected_action
local unavailable_action
package.loaded.fzf = {
  provided_win_fzf = function(source)
    assert(vim.tbl_contains(source, selected_action), "Git toggle must appear in the command menu")
    assert(not vim.tbl_contains(source, unavailable_action), "only the action matching the current state may appear")
    return { selected_action }
  end,
}

local command_menu = require("modules/workflow/command-menu")
command_menu.setup()
require("lib/commands").setup({ git_module, ordinary_module })
local state_dir = vim.fn.stdpath("state") .. "/command-toggles"
vim.fn.mkdir(state_dir, "p")
vim.fn.writefile({ "true" }, state_dir .. "/git.linehl.json")
lib.lazy.setup({ git_module.plugins[1] }, {
  root = lib.env.dirs.vim.lazy.root,
  defaults = { lazy = true },
  install = { missing = false },
  change_detection = { enabled = false },
  performance = { rtp = { reset = false } },
  rocks = { enabled = false },
})
assert(package.loaded.gitsigns == nil, "registering toggle definitions must not load the plugin")
vim.cmd("Gitsigns toggle_linehl")
assert(
  require("gitsigns.config").config.linehl == false,
  "shared initialization must restore saved state before the first direct plugin command executes"
)

local run_menu_action = function(mapping)
  command_menu.mappings[mapping or 1][3]()

  local did_dispatch = false
  vim.schedule(function()
    did_dispatch = true
  end)
  assert(vim.wait(1000, function()
    return did_dispatch
  end))
  vim.cmd.close()
end

selected_action = "Test: ordinary action"
unavailable_action = "Test: hidden action"
run_menu_action()
assert(did_run_action, "ordinary function actions must remain supported")
selected_action = "Test: visual action"
run_menu_action(2)
assert(vim.g.command_menu_visual == 1, "visual string actions must remain supported")

local gitsigns = require("gitsigns")
for _, case in ipairs({
  { name = "gutter signs", toggle = gitsigns.toggle_signs },
  { name = "line number highlighting", toggle = gitsigns.toggle_numhl },
  { name = "whole-line highlighting", toggle = gitsigns.toggle_linehl },
  { name = "word highlighting", toggle = gitsigns.toggle_word_diff },
}) do
  for _, is_enabled in ipairs({ false, true }) do
    case.toggle(is_enabled)
    local verb = is_enabled and "Disable" or "Enable"
    local unavailable_verb = is_enabled and "Enable" or "Disable"
    selected_action = "Git: " .. verb .. " " .. case.name
    unavailable_action = "Git: " .. unavailable_verb .. " " .. case.name
    run_menu_action()
    assert(case.toggle() == is_enabled, selected_action .. " must set its advertised state")
  end
end

gitsigns.toggle_word_diff(false)
package.loaded.fzf.provided_win_fzf = function(source)
  local action = "Git: Enable word highlighting"
  assert(vim.tbl_contains(source, action))
  gitsigns.toggle_word_diff(true)
  return { action }
end
run_menu_action()
assert(
  gitsigns.toggle_word_diff() == false,
  "Enable must remain enabled if the setting changes while the menu is open"
)

vim.api.nvim_del_augroup_by_name("command-toggles")
vim.fn.delete(state_root, "rf")

print("ok: generic toggles retain live Git labels, explicit state, lazy loading, and ordinary actions")

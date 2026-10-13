local root = vim.fn.tempname()
vim.env.XDG_STATE_HOME = root .. "/state"
vim.env.XDG_CACHE_HOME = root .. "/cache"
vim.fn.mkdir(root .. "/plugin", "p")
require("lib")
vim.opt.runtimepath:prepend(lib.env.dirs.vim.lazy.plugin)

local is_enabled
package.preload["test-options"] = function()
  return {
    setup = function(opts)
      is_enabled = opts.is_enabled
      vim.api.nvim_create_user_command("TestOptionToggle", function()
        is_enabled = not is_enabled
      end, {})
    end,
  }
end

local commands = require("lib/commands")
commands.setup({
  {
    actions = {
      {
        kind = "toggle",
        id = "test.options",
        name = "test option",
        plugin = "test-options.nvim",
        persist = true,
        is_enabled = function()
          return is_enabled
        end,
        set_enabled = function(should_enable)
          is_enabled = should_enable
        end,
      },
    },
  },
})
local state_dir = vim.fn.stdpath("state") .. "/command-toggles"
vim.fn.mkdir(state_dir, "p")
vim.fn.writefile({ "true" }, state_dir .. "/test.options.json")
lib.lazy.setup({
  {
    name = "test-parent",
    dir = root,
    dependencies = {
      {
        name = "test-options.nvim",
        dir = root .. "/plugin",
        main = "test-options",
        opts = { is_enabled = false },
        cmd = { "TestOptionToggle" },
      },
    },
  },
}, {
  defaults = { lazy = true },
  install = { missing = false },
  change_detection = { enabled = false },
  performance = { rtp = { reset = false } },
  rocks = { enabled = false },
})
assert(is_enabled == nil, "command registration must preserve lazy loading")
vim.cmd("TestOptionToggle")
assert(is_enabled == false, "default plugin setup must restore saved state before the initiating command runs")
commands.get_actions("n")["Enable test option"]()
assert(is_enabled and vim.json.decode(vim.fn.readfile(state_dir .. "/test.options.json")[1]) == true)

vim.api.nvim_del_augroup_by_name("command-toggles")
vim.fn.delete(root, "rf")
print("ok: plugin-dependent commands support default opts setup and nested dependencies without feature wiring")

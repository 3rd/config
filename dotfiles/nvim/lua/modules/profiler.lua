-- https://github.com/neovim/neovim/issues/15543
-- https://github.com/nvim-lua/plenary.nvim/issues/461
-- https://github.com/nvim-lua/plenary.nvim/issues/225
-- https://github.com/stevearc/profile.nvim

-- LUA_PATH="$(dirname (readlink - f (which luajit)))/../share/lua/5.1/jit/vmdef.lua" nvim
-- inferno-flamegraph profile.log > flame.svg
-- https://blast.hk/moonloader/luajit/ext_profiler.html
local active = false

local profiler_start = function()
  require("plenary.profile.p").start("100,i1,s,m0,G,p,f,l", "profile.log")
  active = true
  vim.notify("Profiler started", vim.log.levels.INFO, { title = "Profiler" })
  vim.cmd([[
    command! ProfilerStop lua require("modules.profiler").exports.stop()
  ]])
end

local profiler_stop = function()
  require("plenary.profile").stop()
  active = false
  vim.cmd([[command! -nargs=0 ProfilerStop]])
  vim.notify("Profiler stopped", vim.log.levels.INFO, { title = "Profiler" })
end

local is_running = function()
  return active
end

local is_stopped = function()
  return not active
end

return lib.module.create({
  name = "profiler",
  hosts = "*",
  plugins = {
    { "nvim-lua/plenary.nvim" },
  },
  actions = {
    { "n", "Profiler: Start profiling", profiler_start, is_stopped },
    { "n", "Profiler: Stop profiling", profiler_stop, is_running },
  },
  exports = {
    start = profiler_start,
    stop = profiler_stop,
  },
})

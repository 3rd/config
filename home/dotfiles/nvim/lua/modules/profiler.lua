-- https://github.com/neovim/neovim/issues/15543
-- https://github.com/nvim-lua/plenary.nvim/issues/461
-- https://github.com/nvim-lua/plenary.nvim/issues/225
-- https://github.com/stevearc/profile.nvim

-- LUA_PATH="/nix/store/sqxjph7y9qgl07rz2ynhpc7hidm5wwp5-luajit-2.1.0-2022-10-04/share/lua/5.1"
-- inferno-flamegraph profile.log > flame.svg
local profiler_start = function()
  vim.notify("Profiler started", vim.log.levels.INFO, { title = "Profiler" })
  require("plenary.profile").start("profile.log", { flame = true })
  vim.cmd([[
    command! ProfilerStop lua require("modules.profiler").stop()
  ]])
end

local profiler_stop = function()
  require("plenary.profile").stop()
  vim.cmd([[command! -nargs=0 ProfilerStop]])
  vim.notify("Profiler stopped", vim.log.levels.INFO, { title = "Profiler" })
end

return lib.module.create({
  name = "profiler",
  plugins = {
    { "nvim-lua/plenary.nvim" },
  },
  actions = {
    { "n", "Profiler: Start profiling", profiler_start },
    { "n", "Profiler: Stop profiling", profiler_stop },
  },
})

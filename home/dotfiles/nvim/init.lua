local has_impatient, impatient = pcall(require, "impatient")
local lib = require("lib")

local profile = {
  lua = false,
  impatient = false,
  packer = false,
}

if profile.lua then
  require("profiler").configuration({ fW = 60, fnW = 20, lW = 20 })
  require("profiler").start()
end
if profile.impatient then
  if has_impatient then impatient.enable_profile() end
end

require("modules/options").setup()
require("modules/mappings").setup()

lib.packer.init()
lib.module.load_modules()
for _, plugin in ipairs({ "syslang" }) do
  local plugin_path =
    string.format("%s/%s", string.format("%s/plugins", vim.fn.stdpath("config")), plugin)
  lib.packer.register_plugin({ plugin_path })
end
lib.packer.load(profile.packer)

if profile.lua then
  require("profiler").stop()
  require("profiler").report("profiler.log")
end

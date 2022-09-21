local lib = require("lib")

require("modules/options").setup()
require("modules/mappings").setup()

lib.packer.init()
lib.module.load_modules()
for _, plugin in ipairs({ "syslang" }) do
  local plugin_path = string.format("%s/%s", string.format("%s/plugins", vim.fn.stdpath("config")), plugin)
  lib.packer.register_plugin({ plugin_path })
end
lib.packer.load()

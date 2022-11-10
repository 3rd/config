local module = {
  is_dev = os.getenv("DEV") ~= nil,
  dirs = {
    home = os.getenv("HOME"),
    config = vim.fn.stdpath("config"),
    packer_pack = vim.fn.stdpath("config") .. "/lua/.packer/pack/packer",
  },
}

module.get = function(key) return os.getenv(key) end

return module

local module = {
  is_dev = os.getenv("DEV") ~= nil,
  dirs = {
    home = os.getenv("HOME"),
    config = vim.fn.stdpath("config"),
  },
}

module.get = function(key)
  return os.getenv(key)
end

return module

local resolve = require("lib/path").resolve

local get = function(name)
  return os.getenv(name)
end

local resolve_cache_dir = function(path)
  return resolve(vim.fn.stdpath("cache"), path)
end

local resolve_data_dir = function(path)
  return resolve(vim.fn.stdpath("data"), path)
end

return {
  dirs = {
    home = get("HOME"),
    vim = {
      backup = resolve_cache_dir("backup"),
      cache = vim.fn.stdpath("cache"),
      config = vim.fn.stdpath("config"),
      data = vim.fn.stdpath("data"),
      sessions = resolve_cache_dir("session"),
      undo = resolve_cache_dir("undo"),
      view = resolve_cache_dir("view"),
      lazy = {
        root = resolve_data_dir("lazy"),
        plugin = resolve_data_dir("lazy/lazy.nvim"),
      },
    },
  },
  get = get,
}

local numeric_options = {
  "startup_timeout_ms",
  "shutdown_timeout_ms",
  "setup_timeout_ms",
  "unload_timeout_ms",
  "sync_timeout_ms",
}

local validate_timeout = function(value, name)
  if type(value) ~= "number" or not (value > 0 and value < math.huge) then
    error(name .. " must be a positive finite number")
  end
end

local parse_plugin = function(name, opts)
  if type(name) ~= "string" or not name:match("^[%w_-]+$") then error("Invalid plugin name") end
  if type(opts) ~= "table" or type(opts.path) ~= "string" then error("Plugin path must be a string") end

  local path = vim.fn.fnamemodify(vim.fn.expand(opts.path), ":p")
  if vim.fn.filereadable(path) ~= 1 then error("Plugin entrypoint does not exist: " .. path) end
  return { path = path, options = opts.options, status = "unloaded" }
end

local create = function()
  return {
    bun = "bun",
    startup_timeout_ms = 5000,
    shutdown_timeout_ms = 1000,
    setup_timeout_ms = 5000,
    unload_timeout_ms = 1000,
    sync_timeout_ms = 1000,
  }
end

local configure = function(config, opts)
  local plugins = {}

  for name, plugin in pairs(opts.plugins or {}) do
    plugins[name] = parse_plugin(name, plugin)
  end

  for _, key in ipairs(numeric_options) do
    if opts[key] ~= nil then validate_timeout(opts[key], key) end
  end

  config.bun = opts.bun or config.bun

  for _, key in ipairs(numeric_options) do
    config[key] = opts[key] or config[key]
  end

  return plugins
end

return { create = create, configure = configure, parse_plugin = parse_plugin, validate_timeout = validate_timeout }

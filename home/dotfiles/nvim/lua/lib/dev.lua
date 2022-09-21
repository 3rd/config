local create_logger = require("lib/log").create_logger
local is = require("lib/is")

local default_formatter = function(opts, ...)
  local output = ""
  if opts.prefix then
    output = opts.prefix .. ": "
  end
  for _, v in ipairs({ ... }) do
    local format_handler = tostring
    if is.no.primitive(v) then
      format_handler = vim.inspect
    end
    output = output .. format_handler(v)
  end
  return output
end

local module = {
  log = create_logger({
    prefix = "[log]",
    formatter = default_formatter,
    handler = print,
    output_file = "/tmp/nvim-log.txt",
  }),
  throw = create_logger({
    prefix = "[error]",
    formatter = default_formatter,
    handler = error,
    output_file = "/tmp/nvim-log.txt",
  }),
}

module.inspect = function(value)
  print(vim.inspect(value))
  return value
end

return module

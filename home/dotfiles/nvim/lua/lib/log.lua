local is = require("lib/is")

local logger_defaults = {
  handler = nil,
  output_file = nil,
  prefix = "",
}

local default_log_formatter = function(opts, ...)
  local parts = {}
  parts[#parts + 1] = vim.fn.strftime("%H:%M:%S")
  if opts.prefix then parts[#parts + 1] = opts.prefix end
  for _, v in ipairs({ ... }) do
    local format_handler = nil
    if is.no.primitive(v) then
      format_handler = vim.inspect
    else
      format_handler = tostring
    end
    parts[#parts + 1] = format_handler(v)
  end
  return table.concat(parts, " ")
end

local create_logger = function(options)
  local opts = vim.tbl_extend("force", logger_defaults, options or {})

  return function(...)
    local output = opts.formatter and opts.formatter(opts, ...) or { ... }

    if opts.output_file then
      local handle = io.open(opts.output_file, "a")
      if handle then
        handle:write(output .. "\n")
        handle:close()
      end
    end

    if is.func(opts.handler) then opts.handler(output) end
  end
end

return {
  create_logger = create_logger,
  default_log_formatter = default_log_formatter,
}

local is = require("lib/is")
local table_merge = require("lib/table").merge

local create_logger_defaults = {
  handler = nil,
  output_file = nil,
  prefix = "",
}

local module = {
  create_logger = function(options)
    local opts = table_merge(create_logger_defaults, options)

    return function(...)
      local output = opts.formatter and opts.formatter(opts, ...) or { ... }

      if opts.output_file then
        local handle = io.open(opts.output_file, "a")
        if handle then
          handle:write(output .. "\n")
          handle:close()
        end
      end

      if is.func(opts.handler) then
        opts.handler(output)
      end
    end
  end,
}

return module

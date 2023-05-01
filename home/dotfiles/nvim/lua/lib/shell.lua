local resolve = require("lib/path")

local escape = function(str)
  return vim.fn.shellescape(str)
end

local exec = function(str, input)
  return vim.fn.system(str, input)
end

local open = function(path)
  exec("xdg-open " .. escape(resolve(path)))
end

return {
  escape = escape,
  exec = exec,
  open = open,
}

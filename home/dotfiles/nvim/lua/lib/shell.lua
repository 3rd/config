local resolve = require("lib/path")

---@param str string
local escape = function(str)
  return vim.fn.shellescape(str)
end

---@param str string
---@param input? string
local exec = function(str, input)
  return vim.fn.system(str, input)
end

---@param path string
local open = function(path)
  vim.ui.open(path)
end

return {
  escape = escape,
  exec = exec,
  open = open,
}

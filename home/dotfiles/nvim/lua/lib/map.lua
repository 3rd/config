---@enum option
local default_options = {
  desc = "",
  buffer = false,
  expr = false,
  nowait = false,
  remap = false,
  silent = false,
  unique = false,
}

---@param mode "n"|"i"|"v"|"x"|"!"|""
---@param lhs string
---@param rhs string|function
---@param optionsOrDescription? table<option, boolean>|string
local map = function(mode, lhs, rhs, optionsOrDescription)
  local opts = default_options
  if type(optionsOrDescription) == "table" then
    opts = table.merge(opts, optionsOrDescription)
  elseif type(optionsOrDescription) == "string" then
    opts.desc = optionsOrDescription
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end

return {
  map = map,
}

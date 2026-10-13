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

---@alias MappingMode "n"|"i"|"v"|"x"|"!"|"s"|""

---@param mode MappingMode|MappingMode[]
---@param lhs string
---@param rhs string|function
---@param optionsOrDescription? table<option, boolean>|string
local map = function(mode, lhs, rhs, optionsOrDescription)
  local opts = table.clone(default_options)
  if type(optionsOrDescription) == "table" then
    opts = table.merge(opts, optionsOrDescription)
  elseif type(optionsOrDescription) == "string" then
    opts.desc = optionsOrDescription
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end

local map_all = function(mappings, options)
  options = options or {}

  for _, mapping in ipairs(mappings) do
    local opts_or_desc = mapping[4]
    local opts = table.merge(
      options.defaults or {},
      type(opts_or_desc) == "string" and { desc = opts_or_desc } or opts_or_desc or {}
    )

    if options.buffer ~= nil then opts.buffer = options.buffer end

    map(mapping[1], mapping[2], mapping[3], opts)
  end
end

return {
  map = map,
  map_all = map_all,
}

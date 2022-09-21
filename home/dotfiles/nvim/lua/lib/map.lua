-- local random = require("lib/random")
local _table = require("lib/table")

local default_options = { noremap = true, silent = true }

local module = {
  mapped_functions = {},
}

module.map = function(mode, mapping, action, options)
  options = _table.merge(default_options, options or {})
  -- vim.keymap.set(mode, mapping, action, options)
  vim.api.nvim_set_keymap(mode, mapping, action, options)
end

module.maplocal = function(mode, mapping, action, options, bufnr)
  options = _table.merge(default_options, options or {}, { buffer = bufnr })
  vim.api.nvim_buf_set_keymap(bufnr or 0, mode, mapping, action, options)
  -- vim.keymap.set(mode, mapping, action, options)
end

module.fnmap = function(mode, mapping, fn, options, bufnr)
  options = _table.merge(default_options, options or {})
  if type(bufnr) == "number" then
    options = _table.merge(options, { buffer = bufnr })
  end
  vim.keymap.set(mode, mapping, fn, options)
end

module.fnmaplocal = function(mode, mapping, fn, options)
  module.fnmap(mode, mapping, fn, options, 0)
end

module.bulk = function(mappings, is_local)
  for _, pair in ipairs(mappings) do
    local mode, mapping, action, options = unpack(pair)
    local mapper = module.map
    if type(action) == "function" then
      mapper = module.fnmap
    end
    if is_local == true then
      if type(action) == "function" then
        mapper = module.fnmaplocal
      else
        mapper = module.maplocal
      end
    end
    mapper(mode, mapping, action, options)
  end
end

return module

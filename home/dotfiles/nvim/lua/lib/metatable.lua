local M = {}

M.decorate_non_enumerable = function(target, nonIterableProps)
  local metatable = getmetatable(target) or {}
  local originalIndex = metatable.__index

  metatable.__index = function(t, key)
    if nonIterableProps[key] then return nonIterableProps[key] end
    if originalIndex then return originalIndex(t, key) end
    return t[key]
  end

  setmetatable(target, metatable)
end

return M

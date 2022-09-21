local module = {}

module.push = function(self, other)
  table.insert(self, other)
end

module.includes = function(self, needle)
  for _, current_value in ipairs(self) do
    if current_value == needle then
      return true
    end
  end
  return false
end

module.index_of = function(self, needle)
  if type(self) ~= "table" then
    error("table expected, got " .. type(self), 2)
  end
  for index, value in pairs(self) do
    if needle == value then
      return index
    end
  end
  return nil
end

module.find = function(self, fn)
  if type(self) ~= "table" then
    error("table expected, got " .. type(self), 2)
  end
  for _, value in pairs(self) do
    if fn(value) then
      return value
    end
  end
  return nil
end

module.find_index = function(self, fn)
  if type(self) ~= "table" then
    error("table expected, got " .. type(self), 2)
  end
  for index, value in pairs(self) do
    if fn(value) then
      return index
    end
  end
  return nil
end

module.map = function(self, fn)
  local result = {}
  for key, value in pairs(self) do
    result[key] = fn(value)
  end
  return result
end

module.filter = function(self, fn)
  return vim.tbl_filter(fn, self)
end

module.reverse = function(self)
  local result = {}
  local len = #self
  for k, v in ipairs(self) do
    result[len + 1 - k] = v
  end
  return result
end

module.merge = function(...)
  return vim.tbl_extend("force", ...)
end

module.merge_deep = function(...)
  return vim.tbl_deep_extend("force", ...)
end

-- https://stackoverflow.com/questions/1410862/concatenation-of-tables-in-lua
module.concat = function(...)
  local result = {}
  for n = 1, select("#", ...) do
    local arg = select(n, ...)
    if type(arg) == "table" then
      for _, v in ipairs(arg) do
        result[#result + 1] = v
      end
    else
      result[#result + 1] = arg
    end
  end
  return result
end

module.clone = function(target)
  return vim.fn.deepcopy(target)
end

return module

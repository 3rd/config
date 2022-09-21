-- escape ( ) . + - * ? [ ] ^ $
local module = {
  includes = function(self, needle)
    return string.match(self, needle)
  end,
  starts_with = function(self, needle)
    return vim.startswith(self, needle)
    -- return self:sub(1, #needle) == needle
  end,
  ends_with = function(self, needle)
    return vim.endswith(self, needle)
    -- return self:sub(- #needle) == needle
  end,
  escape = function(self)
    return self:gsub("%W", "")
  end,
  trim = function(self)
    return (string.gsub(self, "^%s*(.-)%s*$", "%1"))
  end,
  to_lowercase = function(self)
    return vim.fn.tolower(self)
  end,
  to_uppercase = function(self)
    return vim.fn.toupper(self)
  end,
  split = function(self, separator)
    return vim.fn.split(self, separator or "\\zs")
  end,
  lines = function(self)
    return vim.fn.split(self, "\n" or "\\zs")
  end,
  join = function(table, separator)
    return vim.fn.join(table, separator or "")
  end,
  replace = function(self, from, to)
    return self:gsub(from, to)
  end,
}

module.register = function()
  -- http://lua-users.org/wiki/StringIndexing
  getmetatable("").__index = function(str, i)
    if type(i) == "number" then
      return string.sub(str, i + 1, i + 1)
    else
      return string[i]
    end
  end

  getmetatable("").__call = function(str, i, j)
    return string.sub(str, i + 1, j + 1)
  end
end

return module

function string.includes(s, needle)
  return string.match(s, needle) ~= nil
end

function string.starts_with(s, needle)
  return vim.startswith(s, needle)
end

function string.ends_with(s, needle)
  return vim.endswith(s, needle)
end

function string.filter_alnum(s)
  return s:gsub("%W", "")
end

function string.trim(s)
  -- return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
  return vim.trim(s)
end

function string.to_lowercase(s)
  return vim.fn.tolower(s)
end

function string.to_uppercase(s)
  return vim.fn.toupper(s)
end

---@param s string
---@param separator string
---@param opts? { plain?: boolean, trimempty?: boolean}
---@return string[]
function string.split(s, separator, opts)
  return vim.split(s, separator or "\\zs", opts or { plain = true })
end

function string.join(s, separator)
  return vim.fn.join(s, separator or "")
end

---@param s string
---@param from string
---@param to string
---@return string
function string.replace(s, from, to)
  return s:gsub(from, to)[1]
end

function string.lines(s)
  return vim.split(s, "\n")
end

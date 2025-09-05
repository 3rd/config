function table.push(t, other)
  table.insert(t, other)
end

function table.includes(t, needle)
  for _, current_value in ipairs(t) do
    if current_value == needle then return true end
  end
  return false
end

function table.index_of(t, needle)
  if type(t) ~= "table" then error("table expected, got " .. type(t), 2) end
  for index, value in pairs(t) do
    if needle == value then return index end
  end
  return nil
end

function table.find(t, fn)
  if type(t) ~= "table" then error("table expected, got " .. type(t), 2) end
  for _, value in pairs(t) do
    if fn(value) then return value end
  end
  return nil
end

function table.find_index(t, fn)
  if type(t) ~= "table" then error("table expected, got " .. type(t), 2) end
  for index, value in pairs(t) do
    if fn(value) then return index end
  end
  return nil
end

function table.map(t, fn)
  local result = {}
  for key, value in pairs(t) do
    result[key] = fn(value)
  end
  return result
end

function table.filter(t, fn)
  return vim.tbl_filter(fn, t)
end

function table.reverse(t)
  local result = {}
  local len = #t
  for k, v in ipairs(t) do
    result[len + 1 - k] = v
  end
  return result
end

function table.merge(...)
  return vim.tbl_extend("force", ...)
end

function table.merge_deep(...)
  return vim.tbl_deep_extend("force", ...)
end

-- https://stackoverflow.com/questions/1410862/concatenation-of-tables-in-lua
function table.join(...)
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

---@diagnostic disable-next-line: duplicate-set-field -- thanks gitsigns/gen_help.lua /s
function table.slice(t, first, last)
  local result = {}
  for i = first or 1, last or #t do
    result[#result + 1] = t[i]
  end
  return result
end

function table.clone(target)
  return vim.fn.deepcopy(target)
end

function table.keys(t)
  local result = {}
  for key in pairs(t) do
    result[#result + 1] = key
  end
  return result
end

local candidates = vim.json.decode(table.concat(vim.fn.readfile(arg[1]), "\n"))
local functions = {}
local namespaces = { [vim] = { "vim" } }

local function record_function(path, target)
  local is_callable_table = type(target) == "table"
    and type(getmetatable(target)) == "table"
    and type(getmetatable(target).__call) == "function"
  if is_callable_table then target = getmetatable(target).__call end
  if type(target) ~= "function" then return end

  local info = debug.getinfo(target, "S")
  local source = info.source:gsub("^@", ""):gsub("^.-/lua/", "")
  if source:sub(1, 4) == "vim/" and source:sub(-4) ~= ".lua" then source = source .. ".lua" end
  functions[table.concat(path, ".")] = {
    path = path,
    source = source,
    line = info.linedefined,
    isCallableTable = is_callable_table,
  }
end

for _, path in ipairs(candidates) do
  local target = vim
  local prefix = { "vim" }
  for index = 2, #path do
    if type(target) ~= "table" then break end

    target = target[path[index]]
    table.insert(prefix, path[index])
    if type(target) == "table" then namespaces[target] = vim.list_slice(prefix) end
  end

  if #prefix == #path then record_function(path, target) end
end

for namespace, prefix in pairs(namespaces) do
  for name, value in pairs(namespace) do
    if type(name) == "string" and name:sub(1, 1) ~= "_" then
      local path = vim.list_slice(prefix)
      table.insert(path, name)
      record_function(path, value)
    end
  end
end

local entries = vim.tbl_values(functions)
table.sort(entries, function(left, right)
  return table.concat(left.path, ".") < table.concat(right.path, ".")
end)
vim.fn.writefile(
  { vim.json.encode({ version = vim.version(), functions = entries, commands = vim.fn.getcompletion("", "command") }) },
  arg[2]
)

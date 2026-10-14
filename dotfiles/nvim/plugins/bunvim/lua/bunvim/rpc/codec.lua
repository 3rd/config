local M = {}
local bytes_metatable = {}
local reference_metatable = {}
local dictionary_metatable = getmetatable(vim.empty_dict())

M.unpack_args = function(args, count)
  for index = 1, count do
    if args[index] == vim.NIL then args[index] = nil end
  end

  return unpack(args, 1, count)
end

M.pack_results = function(count, ...)
  local should_pack = count == "all" or count > 1
  if not should_pack then return (...) end

  if count == "all" then count = select("#", ...) end

  local results = { ... }

  for index = 1, count do
    if results[index] == nil then results[index] = vim.NIL end
  end

  return results
end

local validate_reference = function(token)
  if
    type(token) ~= "table"
    or type(token.scope) ~= "string"
    or token.scope == ""
    or type(token.id) ~= "number"
    or token.id < 1
    or token.id > 9007199254740991
    or token.id ~= math.floor(token.id)
    or type(token.type) ~= "string"
    or token.type == ""
  then
    error("Invalid RPC reference")
  end

  return token
end

M.bytes = function(value)
  if type(value) ~= "string" then error("RPC bytes must be a string") end

  return setmetatable({ value = value }, bytes_metatable)
end

M.bytes_value = function(value)
  if getmetatable(value) ~= bytes_metatable then error("Expected RPC bytes") end

  return value.value
end

M.reference = function(token)
  validate_reference(token)
  return setmetatable({ token = token }, reference_metatable)
end

local is_scalar = function(value)
  return value == nil
    or value == vim.NIL
    or type(value) == "string"
    or type(value) == "boolean"
    or (type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge)
end

local get_table_shape = function(value)
  local declared_type = rawget(value, vim.type_idx)
  if declared_type == vim.types.float then return "float", rawget(value, vim.val_idx) end
  if declared_type == vim.types.dictionary then return "object" end
  if declared_type == vim.types.array then
    local count = 0

    while rawget(value, count + 1) ~= nil do
      count = count + 1
    end

    return "array", count
  end

  local maximum_index = 0
  local has_string_keys = false

  for key in next, value do
    if type(key) == "string" then
      has_string_keys = true
    elseif type(key) == "number" and key >= 1 and key < math.huge and key == math.floor(key) then
      maximum_index = math.max(maximum_index, key)
    else
      error("Cannot convert given Lua table")
    end
  end

  if has_string_keys and maximum_index > 0 then error("Cannot convert given Lua table") end
  if maximum_index > 0 then return "array", maximum_index end
  if has_string_keys or getmetatable(value) == dictionary_metatable then return "object" end

  return "array", 0
end

M.encode = function(value)
  local parents = {}
  local encode

  encode = function(item)
    if item == nil then return vim.NIL end
    if is_scalar(item) then return item end
    if type(item) ~= "table" or parents[item] then error("Cannot encode RPC value") end

    local metatable = getmetatable(item)
    if metatable == bytes_metatable then return { "bytes", vim.base64.encode(M.bytes_value(item)) } end
    if metatable == reference_metatable then
      local token = validate_reference(item.token)
      return { "reference", token.scope, token.id, token.type }
    end

    parents[item] = true
    local values = {}
    local kind, count = get_table_shape(item)
    if kind == "float" then
      if type(count) ~= "number" then error("Cannot convert given Lua table") end

      parents[item] = nil
      return encode(count)
    end

    if kind == "array" then
      for index = 1, count do
        values[index] = encode(rawget(item, index))
      end
    else
      for key, child in next, item do
        if type(key) == "string" then values[#values + 1] = { key, encode(child) } end
      end
    end

    parents[item] = nil
    return { kind, values }
  end

  return encode(value)
end

M.decode = function(value, opts)
  opts = opts or {}
  local parents = {}
  local decode

  decode = function(item)
    if item == nil then return vim.NIL end
    if is_scalar(item) then return item end
    if type(item) ~= "table" or not vim.islist(item) or parents[item] then error("Invalid encoded RPC value") end

    parents[item] = true
    local kind, payload = item[1], item[2]
    if kind == "reference" and #item == 4 then
      local token = validate_reference({ scope = payload, id = item[3], type = item[4] })
      if not opts.decode_reference then error("RPC references are not supported here") end

      parents[item] = nil
      return opts.decode_reference(token)
    end

    if #item ~= 2 then error("Invalid encoded RPC value") end

    if kind == "bytes" and type(payload) == "string" then
      local ok, bytes = pcall(vim.base64.decode, payload)
      if not ok or vim.base64.encode(bytes) ~= payload then error("Invalid encoded RPC bytes") end

      parents[item] = nil

      if opts.should_unwrap_bytes then return bytes end

      return M.bytes(bytes)
    end

    if type(payload) ~= "table" or not vim.islist(payload) then error("Invalid encoded RPC value") end

    local decoded
    if kind == "array" then
      decoded = {}

      for index, child in ipairs(payload) do
        decoded[index] = decode(child)
      end
    elseif kind == "object" then
      decoded = #payload == 0 and vim.empty_dict() or {}

      for _, entry in ipairs(payload) do
        if
          type(entry) ~= "table"
          or not vim.islist(entry)
          or #entry ~= 2
          or type(entry[1]) ~= "string"
          or decoded[entry[1]] ~= nil
        then
          error("Invalid encoded RPC object entry")
        end

        decoded[entry[1]] = decode(entry[2])
      end
    else
      error("Invalid encoded RPC value")
    end

    parents[item] = nil
    return decoded
  end

  return decode(value)
end

return M

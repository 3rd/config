local is_bool = function(value)
  return value == true or value == false
end

local is_number = function(value)
  return type(value) == "number"
end

local is_string = function(value)
  return type(value) == "string"
end

local is_null = function(value)
  return value == nil
end

local is_function = function(value)
  return type(value) == "function"
end

local is_thread = function(value)
  return type(value) == "thread"
end

local is_table = function(value)
  return type(value) == "table"
end

local is_primitive = function(value)
  return is_bool(value) or is_number(value) or is_string(value) or is_null(value)
end

local is_empty = function(value)
  if is_string(value) then
    return value == ""
  elseif is_table(value) then
    return next(value) == nil
  else
    error("Unexpected type in is_empty  " .. type(value))
  end
end

local negate = function(fn)
  return function(value)
    return not fn(value)
  end
end

local is = {
  bool = is_bool,
  number = is_number,
  string = is_string,
  null = is_null,
  func = is_function,
  thread = is_thread,
  table = is_table,
  primitive = is_primitive,
  empty = is_empty,
}

local no = vim.deepcopy(is)
for k, v in pairs(is) do
  no[k] = negate(v)
end

is["no"] = no

return is

local is = {}

is.bool = function(value)
  return value == true or value == false
end

is.number = function(value)
  return type(value) == "number"
end

is.string = function(value)
  return type(value) == "string"
end

is.null = function(value)
  return value == nil
end

is.func = function(value)
  return type(value) == "function"
end

is.thread = function(value)
  return type(value) == "thread"
end

is.table = function(value)
  return type(value) == "table"
end

is.primitive = function(value)
  return is.bool(value) or is.number(value) or is.string(value) or is.null(value)
end

is.empty = function(value)
  if is.string(value) then
    return value == ""
  elseif is.table(value) then
    return next(value) == nil
  else
    error("Unexpected type in is.empty  " .. type(value))
  end
end

local create_negator = function(fn)
  return function(value)
    return not fn(value)
  end
end

is["no"] = {}
for k, v in pairs(is) do
  is["no"][k] = create_negator(v)
end

return is

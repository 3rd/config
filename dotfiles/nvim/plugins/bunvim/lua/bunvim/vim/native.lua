local codec = require("bunvim.rpc.codec")
local M = {}

local resolve_function = function(path)
  local target = vim

  for _, name in ipairs(path) do
    target = target[name]
    if target == nil then error("Unknown vim function: vim." .. table.concat(path, ".")) end
  end

  return target
end

local validate_limit = function(options)
  local limit = options and options.limit or 64
  if type(limit) ~= "number" or limit % 1 ~= 0 or limit < 1 or limit > 1024 then
    error("Native iterator batch limit must be an integer between 1 and 1024")
  end

  return limit
end

local create_walk = function(node, options)
  if type(options) ~= "table" or (options.direction ~= "ancestors" and options.direction ~= "descendants") then
    error("Tree-sitter walk direction must be ancestors or descendants")
  end

  local thread = coroutine.create(function()
    local publish = function(current, depth)
      if not options.namedOnly or current:named() then
        coroutine.yield({ type = current:type(), range = { current:range() }, depth = depth })
      end
    end

    if options.direction == "ancestors" then
      local current, depth = node, 0

      while current do
        if depth > 0 or options.includeSelf then publish(current, depth) end

        current, depth = current:parent(), depth + 1
      end

      return
    end

    local stack = { { node = node, depth = 0 } }

    while #stack > 0 do
      local entry = table.remove(stack)
      if entry.depth > 0 or options.includeSelf then publish(entry.node, entry.depth) end

      for index = entry.node:child_count() - 1, 0, -1 do
        stack[#stack + 1] = { node = entry.node:child(index), depth = entry.depth + 1 }
      end
    end
  end)

  return function()
    if coroutine.status(thread) == "dead" then return end

    local ok, value = coroutine.resume(thread)
    if not ok then error(value) end

    return value
  end
end

local create_capture_snapshots = function(query, node, source, options)
  options = options or {}
  local iterate = query:iter_captures(node, source, options.startRow, options.endRow)

  return function()
    local id, captured, metadata = iterate()
    if id == nil then return end

    return {
      id = id,
      name = query.captures[id],
      type = captured:type(),
      range = { captured:range() },
      text = vim.treesitter.get_node_text(captured, source, { metadata = metadata[id] }),
      metadata = metadata,
    }
  end
end

M.create = function()
  local scopes = {}

  local get_scope = function(context)
    local scope = scopes[context.scope]
    if scope then
      if scope.owner ~= context.owner or scope.channel ~= context.channel then
        error("Native reference scope mismatch")
      end

      return scope
    end

    scope = { owner = context.owner, channel = context.channel, id = context.scope, next_id = 0, references = {} }
    scopes[context.scope] = scope
    return scope
  end

  local resolve = function(context, reference)
    local scope = scopes[reference.scope]
    if not scope or scope.is_disposed then error("Native reference is disposed") end
    if scope.owner ~= context.owner or scope.channel ~= context.channel then
      error("Native reference belongs to another plugin")
    end

    local entry = scope.references[reference.id]
    if not entry or entry.type ~= reference.type then error("Native reference is disposed") end

    if entry.type == "vim.lsp.Client" then
      local client = vim.lsp.get_client_by_id(entry.client_id)
      if not client or client:is_stopped() then error("LSP client is no longer active: " .. entry.client_id) end

      return client, entry, scope
    end

    return entry.value, entry, scope
  end

  local resolve_target = function(context, target)
    if target.path then return resolve_function(target.path) end

    local value = resolve(context, target.reference)
    local method = value[target.method]
    if type(method) ~= "function" then
      error("Unknown native method: " .. target.reference.type .. "." .. target.method)
    end

    return function(...)
      return method(value, ...)
    end, value
  end

  local register = function(scope, value, kind, iterator)
    if scope.is_disposed then error("Native reference scope is disposed") end

    scope.next_id = scope.next_id + 1
    local entry = { type = kind, value = value, iterator = iterator }
    if kind == "vim.lsp.Client" then
      entry.client_id = value.id
      entry.value = nil
    end

    scope.references[scope.next_id] = entry
    return codec.reference({ scope = scope.id, id = scope.next_id, type = kind })
  end

  local prepare_value
  prepare_value = function(scope, value, descriptor)
    if value == nil or value == vim.NIL or descriptor == nil or descriptor == vim.NIL then return value end
    if descriptor == "bytes" then return codec.bytes(value) end
    if descriptor.native then return register(scope, value, descriptor.native) end
    if descriptor.iterator then return register(scope, value, "iterator", descriptor.iterator) end

    local result = {}
    if descriptor.array then
      for index, item in ipairs(value) do
        result[index] = prepare_value(scope, item, descriptor.array)
      end
    elseif descriptor.dictionary then
      result = vim.empty_dict()

      for key, item in pairs(value) do
        result[tostring(key)] = prepare_value(scope, item, descriptor.dictionary)
      end
    elseif descriptor.tuple then
      for index, item in ipairs(value) do
        result[index] = prepare_value(scope, item, descriptor.tuple[index])
      end
    elseif descriptor.fields then
      for key, item in pairs(value) do
        result[key] = prepare_value(scope, item, descriptor.fields[key])
      end
    else
      error("Invalid native value descriptor")
    end

    return result
  end

  local encode = function(scope, value, descriptor)
    local first_id = scope.next_id + 1
    local ok, result = pcall(function()
      return codec.encode(prepare_value(scope, value, descriptor))
    end)
    if not ok then
      for id = first_id, scope.next_id do
        scope.references[id] = nil
      end

      error(result)
    end

    return result
  end

  local encode_result = function(context, value, metadata)
    local scope = get_scope(context)
    local descriptor = metadata.resultTypes and metadata.resultTypes[1]
    if metadata.returns == "all" or metadata.returns > 1 then descriptor = { tuple = metadata.resultTypes or {} } end

    return encode(scope, value, descriptor)
  end

  local decode = function(context, value)
    return codec.decode(value, {
      should_unwrap_bytes = true,
      decode_reference = function(reference)
        return resolve(context, reference)
      end,
    })
  end

  local dispose_reference = function(context, reference)
    local scope = scopes[reference.scope]
    if not scope then return end
    if scope.owner ~= context.owner or scope.channel ~= context.channel then
      error("Native reference belongs to another plugin")
    end

    scope.references[reference.id] = nil
  end

  local release_scope = function(context)
    local scope = scopes[context.scope]
    if not scope then return end
    if scope.owner ~= context.owner or scope.channel ~= context.channel then
      error("Native reference scope mismatch")
    end

    scope.is_disposed = true
    scope.references = {}
    scopes[context.scope] = nil
  end

  local next_batch = function(context, reference, options)
    local iterate, entry = resolve(context, reference)
    if entry.type ~= "iterator" then error("Native reference is not an iterator") end

    local limit = validate_limit(options)
    local items = {}
    local metadata = entry.iterator

    for _ = 1, limit do
      if entry.is_done then break end

      local values = { iterate() }
      if values[1] == nil then
        entry.is_done = true
        break
      end

      if metadata.returns > 1 then
        for index = 1, metadata.returns do
          if values[index] == nil then values[index] = vim.NIL end
        end

        items[#items + 1] = values
      else
        items[#items + 1] = values[1]
      end
    end

    local descriptor = metadata.resultTypes[1]
    if metadata.returns > 1 then descriptor = { tuple = metadata.resultTypes } end

    return encode(get_scope(context), { items = items, isDone = entry.is_done or false }, {
      fields = { items = { array = descriptor or vim.NIL } },
    })
  end

  local start_walk = function(context, reference, options)
    local node, entry = resolve(context, reference)
    if entry.type ~= "TSNode" then error("Tree-sitter walk requires a node") end

    return codec.encode(
      register(get_scope(context), create_walk(node, options), "iterator", { returns = 1, resultTypes = {} })
    )
  end

  local start_captures = function(context, reference, args)
    local query, entry = resolve(context, reference)
    if entry.type ~= "vim.treesitter.Query" then error("Tree-sitter captures require a query") end

    local values = decode(context, args)
    local iterate = create_capture_snapshots(query, values[1], values[2], values[3] ~= vim.NIL and values[3] or nil)
    return codec.encode(register(get_scope(context), iterate, "iterator", {
      returns = 1,
      resultTypes = { { fields = { metadata = { dictionary = vim.NIL } } } },
    }))
  end

  local get_field = function(context, reference, field, descriptor)
    local value = resolve(context, reference)
    return encode(get_scope(context), value[field], descriptor)
  end

  local cancel_channel = function(channel)
    for id, scope in pairs(scopes) do
      if scope.channel == channel then
        scope.is_disposed = true
        scope.references = {}
        scopes[id] = nil
      end
    end
  end

  return {
    get_scope = get_scope,
    resolve_target = resolve_target,
    decode = decode,
    encode_result = encode_result,
    dispose_reference = dispose_reference,
    release_scope = release_scope,
    next_batch = next_batch,
    start_walk = start_walk,
    start_captures = start_captures,
    get_field = get_field,
    cancel_channel = cancel_channel,
  }
end

return M

local codec = require("bunvim.rpc.codec")
local M = {}

local pack_callback = function(metadata, ...)
  if metadata.result == "uv" then
    local err = ...
    if err ~= nil then return { vim.NIL, err, err:match("^[^:]+") } end

    return codec.pack_results(metadata.returns, select(2, ...))
  end

  if metadata.result == "error-first" then
    local err = ...
    if err ~= nil then error(tostring(err)) end

    return codec.pack_results(metadata.returns, select(2, ...))
  end

  if metadata.returns == 0 then return nil end

  if metadata.dictionaries then
    local values = { ... }

    for _, index in ipairs(metadata.dictionaries) do
      local dictionary = vim.empty_dict()

      for key, value in pairs(values[index + 1]) do
        dictionary[tostring(key)] = value
      end

      values[index + 1] = dictionary
    end

    return codec.pack_results(metadata.returns, unpack(values, 1, select("#", ...)))
  end

  return codec.pack_results(metadata.returns, ...)
end

local discard_result = function(request)
  if request.is_discarded or not request.has_result or request.error then return end

  request.is_discarded = true

  if request.metadata.discard == "close-fd" then
    local fd = request.value[1]
    if type(fd) == "number" then
      local is_closed, err = vim.uv.fs_close(fd)
      if not is_closed then error(err) end
    end
  end
end

local close_completed_resource = function(request)
  local resource = request.resource
  if not request.has_result or resource == nil or request.metadata.cancel ~= "process" then return end

  if not resource:is_closing() then resource:close() end
end

local cancel_native = function(request)
  local resource = request.resource
  if request.has_result or resource == nil then return end

  if request.metadata.cancel == "close" then
    if not resource:is_closing() then resource:close() end
  elseif request.metadata.cancel == "request" then
    vim.uv.cancel(resource)
  elseif request.metadata.cancel == "function" then
    resource()
  elseif request.metadata.cancel == "process" then
    resource:kill(9)
  elseif request.metadata.cancel == "client-request" then
    if not request.client:is_stopped() then request.client:cancel_request(resource) end
  end
end

M.create = function(native)
  local pending = {}

  local validate_prerequisite = function(context, metadata, args)
    local prerequisite = metadata.prerequisite
    if prerequisite then
      local options = {}

      for key, index in pairs(prerequisite.options) do
        local value = args[index + 1]
        if value ~= vim.NIL then options[key] = value end
      end

      local participants = native.resolve_target(context, { path = prerequisite.path })(options)
      if next(participants) == nil then error(prerequisite.message) end
    end
  end

  local finish = function(channel, id, is_accepted)
    local request = pending[id]
    if not request or request.channel ~= channel then return end

    pending[id] = nil
    if request.remove_exit_callback then request.remove_exit_callback() end

    close_completed_resource(request)

    if is_accepted then return end

    request.is_canceled = true
    cancel_native(request)
    discard_result(request)
  end

  local watch_client_exit = function(request, id, publish)
    local receiver, channel = request.client, request.channel
    local callbacks = receiver._on_exit_cbs
    if type(callbacks) ~= "table" then
      finish(channel, id, false)
      error("LSP client exit callbacks are unavailable")
    end

    local on_exit = function()
      vim.schedule(function()
        if request.has_result or request.is_canceled then return end

        request.has_result = true
        request.error = "LSP client stopped before completing request: " .. receiver.id
        publish()
      end)
    end

    callbacks[#callbacks + 1] = on_exit
    request.remove_exit_callback = function()
      for index, callback in ipairs(callbacks) do
        if callback == on_exit then
          table.remove(callbacks, index)
          return
        end
      end
    end
  end

  local call_async = function(context, target, encoded_args, function_metadata, id, method)
    native.get_scope(context)
    local fn, receiver = native.resolve_target(context, target)
    local args = native.decode(context, encoded_args)
    local metadata = function_metadata.callback
    local channel = context.channel
    validate_prerequisite(context, metadata, args)

    local request =
      { channel = channel, context = context, metadata = metadata, is_starting = true, client = receiver }
    pending[id] = request

    local publish = function()
      close_completed_resource(request)

      if request.is_canceled then
        discard_result(request)
        return
      end

      if vim.api.nvim_get_chan_info(channel).id == nil then
        finish(channel, id, false)
        return
      end

      local is_encoded, value = pcall(native.encode_result, context, request.value, function_metadata)
      if not is_encoded then
        request.error = tostring(value)
        value = vim.NIL
      end

      local did_send, err = pcall(vim.rpcnotify, channel, method, id, request.error or vim.NIL, value)
      if not did_send then vim.rpcnotify(channel, method, id, tostring(err), vim.NIL) end
    end

    if metadata.cancel == "client-request" then watch_client_exit(request, id, publish) end

    local complete = function(...)
      if request.has_result then return end

      request.has_result = true

      local is_packed, value = pcall(pack_callback, metadata, ...)
      if is_packed then
        request.value = value
      else
        request.error = tostring(value)
      end

      if request.is_starting then return end

      if vim.in_fast_event() then
        vim.schedule(publish)
      else
        publish()
      end
    end

    local count = math.max(#args + 1, metadata.index + 1)

    for index = #args, metadata.index + 1, -1 do
      args[index + 1] = args[index]
    end

    args[metadata.index + 1] = complete
    local results = { pcall(fn, codec.unpack_args(args, count)) }
    local did_start, resource, err, err_name = unpack(results, 1, 4)

    request.is_starting = false

    if not did_start then
      finish(channel, id, false)
      error(resource)
    end

    request.resource = results[(metadata.resourceIndex or 0) + 2]

    if metadata.rejectOnFalse and resource == false then
      finish(channel, id, false)
      error(metadata.rejectOnFalse)
    end

    if metadata.immediateResult ~= nil and not request.has_result then
      local immediate = results[metadata.immediateResult + 2]
      if immediate ~= nil then
        request.has_result = true
        request.value = immediate
      end
    end

    if metadata.hasErrorReturn and type(err) == "string" then
      if metadata.result == "uv" then
        request.has_result = true
        request.value = { vim.NIL, err, err_name or vim.NIL }
      else
        finish(channel, id, false)
        error(err)
      end
    end

    if request.has_result then publish() end
  end

  local cancel_channel = function(channel)
    for id, request in pairs(pending) do
      if request.channel == channel then finish(channel, id, false) end
    end
  end

  local release_scope = function(context)
    for id, request in pairs(pending) do
      if request.context.scope == context.scope and request.channel == context.channel then
        finish(context.channel, id, false)
      end
    end
  end

  return {
    call = call_async,
    finish = finish,
    cancel_channel = cancel_channel,
    release_scope = release_scope,
  }
end

return M

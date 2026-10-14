local codec = require("bunvim.rpc.codec")
local M = {}

local access_state = function(request)
  local namespace, operation, name = request.namespace, request.operation, request.name
  local state = vim[namespace]

  if namespace == "b" or namespace == "w" or namespace == "t" or namespace == "bo" or namespace == "wo" then
    state = state[request.target]
  end

  if namespace == "wo" and request.scope == "local" then state = state[0] end

  if namespace == "opt" or namespace == "opt_local" or namespace == "opt_global" then
    if operation == "get" then return state[name]:get() end

    if operation == "set" then
      state[name] = request.value
    else
      local option = state[name]
      option[operation](option, request.value)
    end

    return
  end

  if operation == "get" then return state[name] end

  if operation == "delete" then
    state[name] = nil
  else
    state[name] = request.value
  end
end

M.call = function(encoded_request)
  local request = codec.decode(encoded_request, { should_unwrap_bytes = true })
  return codec.encode(access_state(request))
end

return M

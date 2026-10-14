local codec = require("bunvim.rpc.codec")
local M = {}

M.create = function()
  local native = require("bunvim.vim.native").create()
  local callbacks = require("bunvim.vim.callbacks").create(native)

  local call = function(context, target, args, metadata)
    native.get_scope(context)
    local fn = native.resolve_target(context, target)
    local values = native.decode(context, args)
    local result = codec.pack_results(metadata.returns, fn(codec.unpack_args(values, #values)))
    return native.encode_result(context, result, metadata)
  end

  local cancel_channel = function(channel)
    callbacks.cancel_channel(channel)
    native.cancel_channel(channel)
  end

  local release_scope = function(context)
    callbacks.release_scope(context)
    native.release_scope(context)
  end

  return {
    call = call,
    call_async = callbacks.call,
    finish = callbacks.finish,
    cancel_channel = cancel_channel,
    release_scope = release_scope,
    dispose_reference = native.dispose_reference,
    next_batch = native.next_batch,
    start_walk = native.start_walk,
    start_captures = native.start_captures,
    get_field = native.get_field,
  }
end

return M

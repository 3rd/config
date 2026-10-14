local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
vim.opt.runtimepath:prepend(root)
local bunvim = require("bunvim")
local codec = require("bunvim.rpc.codec")

local wait_for = function(condition)
  assert(vim.wait(5000, condition), "Vim callback result missing")
end

local start_call = function(method, input)
  local call = { is_done = false, completions = 0 }
  call.request = assert(bunvim.call("fixture", method, {
    input = input,
    on_complete = function(err, result)
      call.error, call.result, call.is_done = err, result, true
      call.completions = call.completions + 1
    end,
  }))
  return call
end

local call = function(method, input)
  local result = start_call(method, input)
  wait_for(function()
    return result.is_done
  end)
  assert(not result.error, result.error)
  return result.result
end

local cancel_call = function(result)
  assert(result.request.cancel())
  wait_for(function()
    return result.is_done
  end)
  assert(result.error == "Request canceled")
  call("barrier")
end

local start_server = function()
  local server = { is_initialized = false, is_closing = false, next_id = 0 }
  server.id = assert(vim.lsp.start({
    name = "bunvim-callback-fixture",
    on_init = function()
      server.is_initialized = true
    end,
    cmd = function(dispatchers)
      return {
        request = function(method, _, callback, notify_reply)
          server.next_id = server.next_id + 1
          local id = server.next_id

          local respond = function(err, result)
            if notify_reply then notify_reply(id) end

            callback(err, result, id)
          end

          if method == "initialize" then
            vim.schedule(function()
              respond(nil, { capabilities = { hoverProvider = true } })
            end)
          else
            assert(method == "textDocument/hover", method)
            server.respond = respond
          end

          return true, id
        end,
        notify = function(method, params)
          if method == "$/cancelRequest" then server.canceled_id = params.id end

          return true
        end,
        is_closing = function()
          return server.is_closing
        end,
        terminate = function()
          server.is_closing = true
          dispatchers.on_exit(0, 0)
        end,
      }
    end,
  }))
  wait_for(function()
    return server.is_initialized
  end)
  return server
end

local run = function()
  bunvim.setup()
  local is_loaded, load_error = false, nil
  bunvim.load("fixture", {
    path = root .. "/tests/vim/vim-callbacks-fixture.ts",
    on_complete = function(err)
      load_error, is_loaded = err, true
    end,
  })
  wait_for(function()
    return is_loaded
  end)
  assert(not load_error, load_error)

  assert(call("schedule") == nil)
  assert(call("delay", 0) == nil)
  local original_defer = vim.defer_fn
  local timer
  vim.defer_fn = function(callback, timeout)
    timer = original_defer(callback, timeout)
    return timer
  end
  local delay = start_call("delay", 60000)
  wait_for(function()
    return timer ~= nil
  end)
  cancel_call(delay)
  assert(timer:is_closing())
  assert(delay.completions == 1)
  vim.defer_fn = original_defer

  local temporary = call("temporaryFile", vim.env.XDG_STATE_HOME .. "/callback-XXXXXX")
  assert(type(temporary[1]) == "number" and vim.uv.fs_stat(temporary[2]).type == "file")
  assert(temporary[3] == vim.NIL)
  local _, _, closed_error = vim.uv.fs_fstat(temporary[1])
  assert(closed_error == "EBADF")

  local resolved = call("resolveAddress")
  assert(resolved.addresses[1][1].addr == "127.0.0.1")
  assert(resolved.addresses[2] == vim.NIL and resolved.addresses[3] == vim.NIL)
  local host, service = vim.uv.getnameinfo({ ip = "127.0.0.1", port = 80 })
  assert(vim.deep_equal(resolved.names, { host, service, vim.NIL }))

  local original_spawn = vim.uv.spawn
  local process
  vim.uv.spawn = function(path, opts, callback)
    local handle, pid, err_name = original_spawn(path, opts, callback)
    process = handle
    return handle, pid, err_name
  end
  assert(vim.deep_equal(call("spawn", "exit 7"), { 7, 0 }))
  assert(process:is_closing())
  process = nil
  local spawned = start_call("spawn", "exec sleep 60")
  wait_for(function()
    return process ~= nil
  end)
  cancel_call(spawned)
  wait_for(function()
    return process:is_closing()
  end)
  assert(spawned.completions == 1)
  vim.uv.spawn = original_spawn
  local missing_process = start_call("spawnMissing")
  wait_for(function()
    return missing_process.is_done
  end)
  assert(missing_process.error and missing_process.error:find("ENOENT", 1, true), missing_process.error)

  local server = start_server()
  local aggregate = start_call("requestAll")
  wait_for(function()
    return server.respond ~= nil
  end)
  server.respond(nil, { contents = "fixture hover" })
  wait_for(function()
    return aggregate.is_done
  end)
  assert(not aggregate.error, aggregate.error)
  local results, context, config = unpack(aggregate.result)
  assert(results[tostring(server.id)].result.contents == "fixture hover")
  assert(context.client_id == server.id and context.method == "textDocument/hover")
  assert(config == vim.NIL)

  server.respond = nil
  local canceled_aggregate = start_call("requestAll")
  wait_for(function()
    return server.respond ~= nil
  end)
  cancel_call(canceled_aggregate)
  assert(server.canceled_id == server.next_id)
  server.respond(nil, { contents = "late hover" })
  call("barrier")
  assert(canceled_aggregate.completions == 1)
  local client = assert(vim.lsp.get_client_by_id(server.id))
  client:stop(true)

  local without_clients = start_call("requestAll")
  wait_for(function()
    return without_clients.is_done
  end)
  assert(
    without_clients.error and without_clients.error:find("No LSP clients support this request", 1, true),
    without_clients.error
  )

  local original_notify = vim.rpcnotify
  local reply
  vim.rpcnotify = function(channel, method, ...)
    if method == "bunvim.vim.callback" then
      reply = { channel, method, ... }
      return true
    end

    return original_notify(channel, method, ...)
  end
  local opening = start_call("open", temporary[2])
  wait_for(function()
    return reply ~= nil
  end)
  vim.rpcnotify = original_notify
  local fd = codec.decode(reply[5])[1]
  assert(type(fd) == "number" and vim.uv.fs_fstat(fd).type == "file")
  cancel_call(opening)
  local _, _, discarded_error = vim.uv.fs_fstat(fd)
  assert(discarded_error == "EBADF")
  original_notify(unpack(reply))
  call("barrier")
  assert(opening.completions == 1)

  local original_input = vim.ui.input
  vim.ui.input = function(_, done)
    done(function() end)
  end
  local invalid = start_call("input")
  wait_for(function()
    return invalid.is_done
  end)
  assert(invalid.error and invalid.error:find("Cannot encode", 1, true), invalid.error)
  vim.ui.input = original_input

  local metadata = vim.json.decode(table.concat(vim.fn.readfile(root .. "/src/vim/generated/vim-functions.json"), "\n"))
  vim.bunvim_callback_fixture = function()
    return nil, "fixture start failure"
  end
  local ok, err = pcall(
    bunvim._vim.call_async,
    { owner = "callback-tests", scope = "start-failure", channel = 0 },
    { path = { "bunvim_callback_fixture" } },
    codec.encode({}),
    metadata.functions.schedule,
    "start-failure",
    "unused"
  )
  assert(not ok and err:find("fixture start failure", 1, true))
  vim.bunvim_callback_fixture = nil

  local original_open = vim.uv.fs_open
  vim.uv.fs_open = function()
    return nil, "EAGAIN: fixture queue full", "EAGAIN"
  end
  assert(vim.deep_equal(call("open", temporary[2]), { vim.NIL, "EAGAIN: fixture queue full", "EAGAIN" }))
  local has_completed, opened_fd, open_error = false, nil, nil
  vim.uv.fs_open = function(path, flags, mode, callback)
    return original_open(path, flags, mode, function(err, result)
      opened_fd, open_error, has_completed = result, err, true
      callback(err, result)
    end)
  end
  bunvim._vim.call_async(
    { owner = "callback-tests", scope = "pending-open", channel = 0 },
    { path = { "uv", "fs_open" } },
    codec.encode({ temporary[2], "r", 0 }),
    metadata.functions["uv.fs_open"],
    "pending-open",
    "unused"
  )
  bunvim._vim.finish(0, "pending-open", false)
  wait_for(function()
    return has_completed and (not opened_fd or vim.uv.fs_fstat(opened_fd) == nil)
  end)
  if opened_fd then
    local _, _, canceled_open_error = vim.uv.fs_fstat(opened_fd)
    assert(canceled_open_error == "EBADF")
  else
    assert(open_error and open_error:find("ECANCELED", 1, true), open_error)
  end

  vim.uv.fs_open = original_open

  timer = nil
  vim.defer_fn = function(callback, timeout)
    timer = original_defer(callback, timeout)
    return timer
  end
  bunvim._vim.call_async(
    { owner = "callback-tests", scope = "orphaned-delay", channel = bunvim.status().channel },
    { path = { "defer_fn" } },
    codec.encode({ 60000 }),
    metadata.functions.defer_fn,
    "orphaned-delay",
    "unused"
  )
  local is_stopped = false
  bunvim.stop({
    on_complete = function()
      is_stopped = true
    end,
  })
  wait_for(function()
    return is_stopped
  end)
  assert(timer:is_closing())
  vim.defer_fn = original_defer
end

local ok, failure = xpcall(run, debug.traceback)

bunvim.stop()

if not ok then
  io.stderr:write(tostring(failure) .. "\n" .. table.concat(bunvim.logs(), "\n") .. "\n")
  vim.cmd("cquit 1")
end

print("Bunvim vim-callbacks passed")
vim.cmd("qa!")

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
vim.opt.runtimepath:prepend(root)
local bunvim = require("bunvim")
local servers = {}

local wait_for = function(condition)
  assert(vim.wait(5000, condition), "Native reference result missing")
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

local expect_error = function(result, pattern)
  wait_for(function()
    return result.is_done
  end)
  assert(result.error and result.error:lower():find(pattern, 1, true), result.error)
  assert(result.completions == 1)
end

local start_server = function(name, opts)
  local server = { is_initialized = false, is_closing = false, next_id = 0, exits = 0 }
  server.id = assert(vim.lsp.start({
    name = name,
    on_init = function()
      server.is_initialized = true
    end,
    on_exit = function()
      server.exits = server.exits + 1
    end,
    cmd = function(dispatchers)
      return {
        request = function(method, _, callback, notify_reply)
          if server.should_reject_requests then return false end

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

            if server.should_respond_immediately then respond(server.response_error, server.response_result) end
          end

          return true, id
        end,
        notify = function(method, params)
          if method == "$/cancelRequest" then
            server.canceled_id = params.id
          elseif method == "workspace/didChangeConfiguration" then
            server.notification = params
          end

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
  }, opts))
  servers[#servers + 1] = server
  wait_for(function()
    return server.is_initialized
  end)
  return server
end

local run = function()
  bunvim.setup()
  local is_loaded, load_error = false, nil
  bunvim.load("fixture", {
    path = root .. "/tests/vim/native-references-fixture.ts",
    on_complete = function(err)
      load_error, is_loaded = err, true
    end,
  })
  wait_for(function()
    return is_loaded
  end)
  assert(not load_error, load_error)

  local syntax = call("syntax")
  local native_tree = vim.treesitter.get_string_parser("local value = 7\nreturn value", "lua"):parse()[1]
  assert(syntax.rootType == "chunk")
  assert(vim.deep_equal(syntax.includedRanges, native_tree:included_ranges(false)))
  assert(vim.deep_equal(syntax.includedByteRanges, native_tree:included_ranges(true)))
  assert(vim.deep_equal(syntax.childFields, { "local_declaration", vim.NIL }))
  assert(syntax.nodeType == "identifier" and syntax.nodeText == "value")
  assert(vim.deep_equal(syntax.nodeRange, { 0, 6, 0, 11 }))
  assert(syntax.parentType == "variable_list")
  assert(vim.deep_equal(syntax.ancestorTypes, {
    "identifier",
    "variable_list",
    "assignment_statement",
    "variable_declaration",
    "chunk",
  }))
  assert(syntax.hasMoreAncestors)
  assert(vim.tbl_contains(syntax.descendantTypes, "return_statement"))
  assert(not vim.tbl_contains(syntax.descendantTypes, "return"))
  assert(not vim.tbl_contains(syntax.descendantTypes, "chunk"))
  assert(#syntax.earlyExitTypes == 1)
  assert(syntax.earlyExitError:lower():find("disposed", 1, true), syntax.earlyExitError)
  assert(vim.deep_equal(syntax.captureNames, { "name" }))
  assert(syntax.hasMoreCaptures)
  local capture_metadata = { ["1"] = { conceal = "x" }, priority = "120" }
  assert(vim.deep_equal(syntax.captures, {
    { name = "name", type = "identifier", range = { 0, 6, 0, 11 }, text = "value", metadata = capture_metadata },
    { name = "name", type = "identifier", range = { 1, 7, 1, 12 }, text = "value", metadata = capture_metadata },
  }))
  assert(vim.deep_equal(syntax.queryPatterns["1"], {
    { "set!", "priority", "120" },
    { "set!", 1, "conceal", "x" },
  }))
  assert(#bunvim.bytes_value(syntax.nodeId) > 0)
  assert(vim.deep_equal(syntax.rawCapture, {
    id = 1,
    type = "identifier",
    treeType = "chunk",
    matchedType = "identifier",
    pattern = 1,
    metadata = capture_metadata,
  }))
  assert(syntax.iteratorError:lower():find("disposed", 1, true), syntax.iteratorError)
  assert(syntax.releasedError:lower():find("disposed", 1, true), syntax.releasedError)

  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "return 9" })
  local parser = assert(vim.treesitter.get_parser(buffer, "lua"))
  assert(call("rememberBufferParser", buffer):find("number", 1, true))
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { 'return "changed"' })
  assert(call("readRetainedParser"):find("string", 1, true))
  assert(vim.deep_equal(call("readRetainedRange"), { parser:parse()[1]:root():range() }))
  call("disposeRetainedParser")
  assert(vim.treesitter.get_parser(buffer, "lua") == parser)
  assert(parser:parse()[1]:root():sexpr():find("string", 1, true))
  expect_error(start_call("readRetainedParser"), "disposed")
  call("rememberInvocationParser")
  expect_error(start_call("readRetainedParser"), "disposed")
  vim.api.nvim_buf_delete(buffer, { force = true })

  local server = start_server("bunvim-native-fixture")
  local other = start_server("bunvim-native-other", { attach = false })
  assert(vim.deep_equal(call("clients"), { { id = server.id, name = "bunvim-native-fixture" } }))
  assert(call("missingClient"))
  assert(call("rememberClient", server.id) == server.id)
  assert(call("clientSupportsHover"))
  local client = assert(vim.lsp.get_client_by_id(server.id))
  client.server_capabilities.codeActionProvider = true
  client.server_capabilities.experimental = { "one", false, { two = 2 } }
  assert(vim.deep_equal(call("clientCapabilities", server.id), client.server_capabilities))
  client.server_capabilities.hoverProvider = false
  assert(not call("clientSupportsHover"))
  client.server_capabilities.hoverProvider = true
  assert(call("notify", server.id))
  assert(vim.deep_equal(server.notification, { settings = { fixture = "notification" } }))
  assert(other.notification == nil)

  server.should_respond_immediately = true
  server.response_result = { contents = "targeted hover" }
  local response = call("request", server.id)
  assert(response[1] == vim.NIL and response[2].contents == "targeted hover")
  assert(response[3].client_id == server.id and response[3].method == "textDocument/hover")
  assert(response[4] == vim.NIL)
  assert(other.respond == nil)

  server.response_error = { code = -32603, message = "fixture response error", data = { reason = "example" } }
  server.response_result = nil
  local rejected = call("request", server.id)
  assert(vim.deep_equal(rejected[1], server.response_error))
  assert(rejected[2] == vim.NIL and rejected[3].client_id == server.id)

  server.should_respond_immediately = false
  server.respond = nil
  local canceled = start_call("request", server.id)
  wait_for(function()
    return server.respond ~= nil
  end)
  assert(canceled.request.cancel())
  expect_error(canceled, "request canceled")
  call("barrier")
  assert(server.canceled_id == server.next_id)
  server.respond(nil, { contents = "late hover" })
  call("barrier")
  assert(canceled.completions == 1)

  server.should_reject_requests = true
  expect_error(start_call("request", server.id), "request")
  server.should_reject_requests = false
  server.respond = nil
  local previous_id = server.next_id
  local stopped = start_call("request", server.id)
  local also_stopped = start_call("request", server.id)
  wait_for(function()
    return server.next_id == previous_id + 2
  end)
  client:stop(true)
  expect_error(stopped, "client")
  expect_error(also_stopped, "client")
  assert(server.exits == 1)
  expect_error(start_call("clientSupportsHover"), "client")

  local unattached = start_server("bunvim-native-unattached", { attach = false })
  local unattached_client = assert(vim.lsp.get_client_by_id(unattached.id))
  assert(vim.tbl_isempty(unattached_client.attached_buffers))
  local exit_callbacks = unattached_client._on_exit_cbs
  unattached_client._on_exit_cbs = nil
  local requests_before_missing_lifecycle = unattached.next_id
  expect_error(start_call("request", unattached.id), "exit")
  assert(unattached.next_id == requests_before_missing_lifecycle)
  unattached_client._on_exit_cbs = exit_callbacks

  local unattached_stopped = start_call("request", unattached.id)
  local also_unattached_stopped = start_call("request", unattached.id)
  wait_for(function()
    return unattached.next_id == requests_before_missing_lifecycle + 2
  end)
  unattached_client:stop(true)
  expect_error(unattached_stopped, "client")
  expect_error(also_unattached_stopped, "client")
  assert(unattached.exits == 1)

  other.respond = nil
  local unloading = start_call("request", other.id)
  wait_for(function()
    return other.respond ~= nil
  end)
  local is_unloaded, unload_error = false, nil
  bunvim.unload("fixture", {
    on_complete = function(err)
      unload_error, is_unloaded = err, true
    end,
  })
  wait_for(function()
    return is_unloaded
  end)
  assert(not unload_error, unload_error)
  expect_error(unloading, "unloaded")
  assert(other.canceled_id == other.next_id)
end

local ok, failure = xpcall(run, debug.traceback)

for _, server in ipairs(servers) do
  local client = vim.lsp.get_client_by_id(server.id)
  if client then client:stop(true) end
end

bunvim.stop()

if not ok then
  io.stderr:write(tostring(failure) .. "\n" .. table.concat(bunvim.logs(), "\n") .. "\n")
  vim.cmd("cquit 1")
end

print("Bunvim native-references passed")
vim.cmd("qa!")

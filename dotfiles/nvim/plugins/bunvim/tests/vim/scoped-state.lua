local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
vim.opt.runtimepath:prepend(root)
local bunvim = require("bunvim")

local await = function(start)
  local is_done, failure, value = false, nil, nil
  start(function(err, result)
    failure, value, is_done = err, result, true
  end)
  assert(
    vim.wait(5000, function()
      return is_done
    end),
    "Scoped state result missing"
  )
  return failure, value
end

local call = function(method, input)
  return await(function(done)
    bunvim.call("fixture", method, { input = input, on_complete = done })
  end)
end

local expect_success = function(err, result)
  assert(not err, err)
  return result
end

local run = function()
  bunvim.setup()
  expect_success(await(function(done)
    bunvim.load("fixture", { path = root .. "/tests/vim/scoped-state-fixture.ts", on_complete = done })
  end))

  local variables = expect_success(call("variables"))
  assert(vim.deep_equal(variables.values.global, { items = { false, vim.NIL, "text" } }))
  assert(variables.values.buffer == "buffer" and variables.values.window == "window")
  assert(variables.values.tab == "tab" and variables.values.predefined == "scoped-state fixture")
  assert(variables.values.environment == "environment")
  assert(variables.missing == vim.NIL and variables.environmentMissing == vim.NIL)
  assert(variables.nullValue == vim.NIL and vim.g.bunvim_null == vim.NIL)
  assert(vim.deep_equal(variables.emptyList, {}) and vim.islist(variables.emptyList))
  assert(vim.deep_equal(variables.emptyMap, vim.empty_dict()) and not vim.islist(variables.emptyMap))
  assert(vim.g.bunvim_value == nil and vim.b.bunvim_value == nil and vim.w.bunvim_value == nil)
  assert(vim.t.bunvim_value == nil and vim.env.BUNVIM_SCOPED_STATE == nil)

  local original_window = vim.api.nvim_get_current_win()
  local original_buffer = vim.api.nvim_get_current_buf()
  vim.cmd("new")
  local next_window = vim.api.nvim_get_current_win()
  local next_buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_set_current_win(original_window)
  local targets = expect_success(call("targets", next_window))
  assert(targets.capturedBuffer == "captured buffer" and targets.currentBuffer == "current buffer")
  assert(targets.capturedWindow == "captured window" and targets.currentWindow == "current window")
  assert(targets.capturedWidth == 3 and targets.currentWidth == 5)
  assert(targets.capturedNumber and not targets.currentNumber)
  assert(vim.b[original_buffer].bunvim_target == "captured buffer")
  assert(vim.b[next_buffer].bunvim_target == "current buffer")
  assert(vim.bo[original_buffer].shiftwidth == 3 and vim.bo[next_buffer].shiftwidth == 5)

  local options = expect_success(call("options"))
  assert(not options.localNumberDefault and options.windowNumberDefault)
  assert(options.inherited == "global-build" and options.localGlobal == "global-build")
  assert(options.both.effective == "both-build" and options.both.global == "both-build")
  assert(options.both["local"] == "")
  assert(options.effective == "global-only-suffix" and options.global == "global-only-suffix")

  local structured = expect_success(call("structured"))
  assert(structured.values.list[1] == "build" and structured.values.list[2] == "*.o")
  local appended = { structured.values.list[3], structured.values.list[4] }
  table.sort(appended)
  assert(#structured.values.list == 4 and vim.deep_equal(appended, { "cache", "node_modules" }))
  assert(vim.deep_equal(structured.values.map, { tab = ">~", eol = "$" }))
  assert(vim.deep_equal(structured.values.flags, { r = true }))
  assert(vim.islist(structured.emptyList) and next(structured.emptyList) == nil)
  assert(not vim.islist(structured.emptyMap) and next(structured.emptyMap) == nil)
  assert(not vim.islist(structured.emptyFlags) and next(structured.emptyFlags) == nil)
  assert(vim.o.wildignore == "" and vim.bo.formatoptions == "" and vim.wo.listchars == "")

  assert(call("failure", "buffer"):find("Invalid buffer", 1, true))
  assert(call("failure", "option"):find("Unknown option", 1, true))
  assert(call("failure", "scope"):find("buf", 1, true))
  assert(call("failure", "type"):find("Invalid 'shiftwidth'", 1, true))
  assert(call("failure", "fixed"):find("Key is fixed: errmsg", 1, true))

  expect_success(await(function(done)
    bunvim.stop({ on_complete = done })
  end))
end

local ok, failure = xpcall(run, debug.traceback)
bunvim.stop()
if not ok then
  io.stderr:write(tostring(failure) .. "\n" .. table.concat(bunvim.logs(), "\n") .. "\n")
  vim.cmd("cquit 1")
end

print("Bunvim scoped-state passed")
vim.cmd("qa!")

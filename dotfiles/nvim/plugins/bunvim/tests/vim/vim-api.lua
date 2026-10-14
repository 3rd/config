local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
vim.opt.runtimepath:prepend(root)
local bunvim = require("bunvim")

local wait_for = function(condition)
  assert(vim.wait(5000, condition), "Vim API result missing")
end

local await = function(start)
  local is_done, failure, value = false, nil, nil
  start(function(err, result)
    failure, value, is_done = err, result, true
  end)
  wait_for(function()
    return is_done
  end)
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
    bunvim.load("fixture", { path = root .. "/tests/vim/vim-api-fixture.ts", on_complete = done })
  end))
  vim.lsp.log.set_level("DEBUG")
  local result = expect_success(call("roundtrip"))
  assert(result.buffer == vim.api.nvim_get_current_buf() and result.setupBuffer == result.buffer)
  assert(vim.deep_equal(result.lines, { "changed", "beta" }))
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, true), result.lines))
  assert(result.cwd == vim.fn.getcwd() and result.basename == "report.txt" and result.width == 3)
  assert(vim.deep_equal(result.filetype, { "typescript", vim.NIL, vim.NIL }))
  assert(result.level == vim.log.levels.INFO)
  assert(result.description == vim.inspect({ name = "example" }))
  assert(result.version.major == vim.version().major and result.version.minor == vim.version().minor)
  assert(result.version[1] == nil)
  assert(result.parsedVersion.major == 1 and result.parsedVersion.minor == 2 and result.parsedVersion.patch == 3)
  assert(vim.deep_equal(result.nodeRange, { 1, 2, 3, 4 }))
  assert(vim.deep_equal(result.layout, vim.fn.winlayout()))
  assert(result.configPath == vim.fn.stdpath("config"))
  local converted = vim.iconv("text", "utf-8", "utf-8")
  if converted == nil then converted = vim.NIL end
  assert(result.converted == converted)
  assert(vim.deep_equal(result.diagnosticFloat, { vim.NIL, vim.NIL }))
  assert(vim.deep_equal(result.difference, {}))
  assert(result.canLog and result.logged == vim.NIL)
  assert(table.concat(vim.fn.readfile(vim.lsp.log.get_filename()), "\n"):find("bunvim synthetic log entry", 1, true))
  assert(vim.deep_equal(result.codelensRefresh, { vim.NIL }))
  assert(expect_success(call("configureLsp")))
  assert(vim.deep_equal(vim.lsp.config.bunvim_fixture.cmd, { "unused" }))
  vim.env.BUNVIM_MISSING_FIXTURE = nil
  local errata = expect_success(call("metadataErrata", vim.env.XDG_STATE_HOME))
  assert(errata.isLetter and errata.isCommand and errata.isWritableDirectory and errata.isMissingFile)
  assert(errata.missingEnvironment == vim.NIL and errata.formatted == "one two")
  assert(vim.deep_equal(errata.unplaced, {}) and vim.deep_equal(errata.emptyLayout, {}))

  local uv_path = vim.env.XDG_STATE_HOME .. "/vim-api-uv.txt"
  vim.fn.writefile({ "sample" }, uv_path)
  local uv_result = expect_success(call("uv", uv_path))
  assert(vim.deep_equal(uv_result.cwd, { vim.uv.cwd(), vim.NIL, vim.NIL }))
  assert(uv_result.version == vim.uv.version_string())
  assert(uv_result.stat[1].type == "file" and uv_result.stat[1].size == 7)
  assert(uv_result.stat[2] == vim.NIL and uv_result.stat[3] == vim.NIL)
  assert(vim.deep_equal(uv_result.descriptorStat, uv_result.stat))
  assert(uv_result.missing[1] == vim.NIL and uv_result.missing[3] == "ENOENT")
  assert(uv_result.missing[2]:find(uv_path .. ".missing", 1, true))
  assert(uv_result.missingOwner[1] == vim.NIL and uv_result.missingOwner[3] == "ENOENT")

  assert(vim.deep_equal(expect_success(call("command")), { 2, 0 }))
  assert(call("fail"):find("Invalid buffer", 1, true))
  assert(expect_success(call("invalidArgument")) == "Vim arguments must be RPC values")
  assert(expect_success(call("argumentGetterFailure")) == "fixture getter failed")

  local native_calls = 0
  local original_system = vim.system
  vim.system = function()
    native_calls = native_calls + 1
    error("Native process operation must not run")
  end
  assert(call("nativeOnly", "system"):find("Unsupported Vim function: vim.system", 1, true))
  assert(call("nativeOnly", "regex"):find("Unsupported Vim function: vim.regex", 1, true))
  assert(call("nativeOnly", "ringbuf"):find("Unsupported Vim function: vim.ringbuf", 1, true))
  assert(call("nativeOnly", "iter"):find("Unsupported Vim function: vim.iter", 1, true))
  assert(call("nativeOnly", "range.new"):find("Unsupported Vim function: vim.range.new", 1, true))
  assert(call("nativeOnly", "range.has"):find("Unsupported Vim function: vim.range.has", 1, true))
  assert(call("nativeOnly", "uv.new_timer"):find("Unsupported Vim function: vim.uv.new_timer", 1, true))
  assert(native_calls == 0)
  vim.system = original_system

  local listener_count = expect_success(call("listeners"))
  vim.ui.input = function(opts, done)
    assert(opts.prompt == "Accept input")
    done("accepted")
  end
  assert(expect_success(call("input", "Accept input")) == "accepted")
  vim.ui.input = function(_, done)
    done("")
  end
  assert(expect_success(call("input", "Empty input")) == "")
  vim.ui.input = function(_, done)
    done(nil)
  end
  assert(expect_success(call("input", "Canceled input")) == nil)
  vim.ui.input = function()
    error("prompt implementation failed")
  end
  assert(call("input", "Failed input"):find("prompt implementation failed", 1, true))
  assert(expect_success(call("listeners")) == listener_count)

  local prompts, results = {}, {}
  vim.ui.input = function(opts, done)
    prompts[opts.prompt] = done
  end
  for _, name in ipairs({ "first", "second" }) do
    bunvim.call("fixture", "input", {
      input = name,
      on_complete = function(err, value)
        results[name] = expect_success(err, value)
      end,
    })
  end
  wait_for(function()
    return prompts.first and prompts.second
  end)
  prompts.second("second answer")
  prompts.first("first answer")
  wait_for(function()
    return results.first and results.second
  end)
  assert(results.first == "first answer" and results.second == "second answer")

  local completions, failure = 0, nil
  local request = bunvim.call("fixture", "input", {
    input = "cancel",
    on_complete = function(err)
      completions = completions + 1
      failure = err
    end,
  })
  wait_for(function()
    return prompts.cancel ~= nil
  end)
  assert(request.cancel())
  wait_for(function()
    return failure ~= nil
  end)
  assert(failure == "Request canceled")
  prompts.cancel("late answer")
  assert(expect_success(call("listeners")) == listener_count)
  assert(completions == 1)

  vim.ui.select = function(items, opts, done)
    assert(opts.prompt == "Pick an item")
    done(items[2], 2)
  end
  assert(vim.deep_equal(expect_success(call("select")), { { id = 2 }, 2 }))
  vim.ui.select = function(_, _, done)
    done(nil, nil)
  end
  assert(vim.deep_equal(expect_success(call("select")), { vim.NIL, vim.NIL }))

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

print("Bunvim vim-api passed")
vim.cmd("qa!")

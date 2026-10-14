local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(root)
local bunvim = require("bunvim")
local now = vim.uv.hrtime

local await = function(start)
  local is_done, failure, value = false, nil, nil
  start(function(err, result)
    failure, value, is_done = err, result, true
  end)
  assert(
    vim.wait(5000, function()
      return is_done
    end),
    "benchmark callback missing"
  )
  assert(not failure, failure)
  return value
end

local call = function(plugin, method, input)
  return await(function(done)
    bunvim.call(plugin, method, { input = input, on_complete = done })
  end)
end

local summarize = function(samples)
  local sorted = vim.deepcopy(samples)
  table.sort(sorted)
  return { median = sorted[math.ceil(#sorted / 2)], p95 = sorted[math.ceil(#sorted * 0.95)], max = sorted[#sorted] }
end

local read_process = function(pid)
  local details = {}
  for _, line in ipairs(vim.fn.readfile("/proc/" .. pid .. "/status")) do
    local key, value = line:match("^([%w_]+):%s+(%d+)")
    if key == "VmRSS" or key == "Seccomp" or key == "Seccomp_filters" then details[key] = tonumber(value) end
  end

  local stat = table.concat(vim.fn.readfile("/proc/" .. pid .. "/stat"), " ")
  local fields = vim.split(stat:match("%) (.*)$"), " ")
  details.cpu_ticks = tonumber(fields[12]) + tonumber(fields[13])
  return details
end

local run_sustained = function()
  await(function(done)
    bunvim.setup({
      plugins = {
        alpha = { path = root .. "/benchmarks/soak-fixture.ts" },
        beta = { path = root .. "/benchmarks/soak-fixture.ts" },
        cpu = { path = root .. "/benchmarks/soak-fixture.ts" },
        documents = { path = root .. "/benchmarks/soak-fixture.ts" },
      },
      on_ready = done,
    })
  end)
  local result =
    { reload_memory = {}, call_ms = {}, cpu_neighbor_ms = {}, edit_ms = {}, cpu_jobs = 0, ticks = 0, max_pending = 0 }
  for index = 1, 110 do
    await(function(done)
      bunvim.load("reload", { path = root .. "/benchmarks/soak-fixture.ts", on_complete = done })
    end)
    assert(call("reload", "echo", "reload") == "reload")
    await(function(done)
      bunvim.unload("reload", { on_complete = done })
    end)
    assert(vim.fn.exists(":BunvimSoakreload") == 0)
    assert(vim.fn.maparg("<Plug>(BunvimSoakreload)", "n") == "")
    assert(#vim.api.nvim_get_autocmds({ event = "User", pattern = "BunvimSoakreload" }) == 0)
    if index >= 10 and index % 10 == 0 then
      table.insert(result.reload_memory, { reload = index, memory = call("alpha", "memory") })
    end
  end

  local lines = {}
  local expected = {}
  for index = 1, 1000 do
    expected[index] = "line " .. index
    lines[index] = expected[index] .. "   "
  end
  local buffer = vim.api.nvim_get_current_buf()
  local started = now()
  local next_cpu_at = 0
  local is_cpu_running = false
  local is_producing = true
  local failure
  local timer = vim.uv.new_timer()
  timer:start(
    0,
    10,
    vim.schedule_wrap(function()
      if failure or not is_producing then return end
      local ok, err = pcall(function()
        result.ticks = result.ticks + 1
        for _, name in ipairs({ "alpha", "beta" }) do
          for _ = 1, 4 do
            local sent = now()
            local is_cpu_sample = is_cpu_running and vim.g.bunvim_cpu_started == true
            bunvim.call(name, "echo", {
              input = "payload",
              on_complete = function(call_error, value)
                if call_error or value ~= "payload" then
                  failure = call_error or "Incorrect result"
                  return
                end
                local elapsed = (now() - sent) / 1e6
                table.insert(result.call_ms, elapsed)
                if is_cpu_sample then table.insert(result.cpu_neighbor_ms, elapsed) end
              end,
            })
            vim.api.nvim_exec_autocmds("User", { pattern = "BunvimSoak" .. name })
          end
        end

        local elapsed = (now() - started) / 1e9
        if elapsed >= next_cpu_at and result.cpu_jobs < 10 then
          assert(not is_cpu_running, "CPU worker did not finish between jobs")
          is_cpu_running = true
          vim.g.bunvim_cpu_started = false
          result.cpu_jobs = result.cpu_jobs + 1
          next_cpu_at = next_cpu_at + 6
          bunvim.call("cpu", "work", {
            on_complete = function(err, value)
              if err or type(value) ~= "number" or value <= 0 then failure = err or "Invalid CPU result" end
              is_cpu_running = false
            end,
          })
        end

        if result.ticks % 100 == 0 then
          vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
          local edit_started = now()
          vim.api.nvim_exec_autocmds("BufWritePre", { buffer = buffer })
          assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), expected))
          table.insert(result.edit_ms, (now() - edit_started) / 1e6)
        end

        result.max_pending = math.max(result.max_pending, bunvim.status().pending)
      end)
      if not ok then failure = tostring(err) end
    end)
  )
  local did_finish = vim.wait(65000, function()
    return failure or (now() - started) / 1e9 >= 60
  end)
  is_producing = false
  timer:stop()
  timer:close()
  assert(did_finish and not failure, failure or "Sustained workload did not finish")
  assert(
    vim.wait(5000, function()
      return bunvim.status().pending == 0 and not is_cpu_running and (failure or #result.call_ms == result.ticks * 8)
    end),
    "Queue or callbacks did not drain"
  )
  assert(not failure, failure)
  assert(not is_cpu_running and result.cpu_jobs == 10)
  result.event_counts = { alpha = call("alpha", "events"), beta = call("beta", "events") }
  assert(
    result.event_counts.alpha == result.ticks * 4,
    vim.inspect({ expected = result.ticks * 4, actual = result.event_counts, status = bunvim.status() })
  )
  assert(
    result.event_counts.beta == result.ticks * 4,
    vim.inspect({ expected = result.ticks * 4, actual = result.event_counts, status = bunvim.status() })
  )
  result.duration_ms = (now() - started) / 1e6
  result.call_summary = summarize(result.call_ms)
  result.cpu_neighbor_summary = summarize(result.cpu_neighbor_ms)
  result.edit_summary = summarize(result.edit_ms)
  result.memory_after = call("alpha", "memory")
  result.plugins = bunvim.status().plugins
  await(function(done)
    bunvim.stop({ on_complete = done })
  end)
  return result
end

local run = function()
  local result = {
    runs = {},
    nvim = vim.version(),
    editor = read_process(vim.fn.getpid()),
    has_preload = vim.env.LD_PRELOAD ~= nil,
  }
  assert(
    result.editor.Seccomp_filters == nil or result.editor.Seccomp_filters == 0,
    "benchmark editor inherits seccomp"
  )
  assert(not result.has_preload, "benchmark editor inherits LD_PRELOAD")
  for _ = 1, 3 do
    local started = now()
    await(function(done)
      bunvim.setup({
        plugins = {
          benchmark = { path = root .. "/benchmarks/fixture.ts" },
        },
        on_ready = done,
      })
    end)
    local run_result = { cold_ms = (now() - started) / 1e6, native_ms = {}, warm_ms = {}, edit_ms = {} }
    local status = bunvim.status()
    local host_before = read_process(status.pid)
    assert(host_before.Seccomp_filters == nil or host_before.Seccomp_filters == 0, "benchmark host inherits seccomp")
    local control_done
    _G.bunvim_benchmark_complete = function(channel, value)
      assert(channel == status.channel and value == "payload")
      control_done = true
    end
    for index = 1, 1100 do
      control_done = false
      started = now()
      vim.rpcnotify(status.channel, "bunvim-benchmark-control", "payload")
      assert(vim.wait(5000, function()
        return control_done
      end))
      local native_ms = (now() - started) / 1e6
      started = now()
      assert(call("benchmark", "echo", "payload") == "payload")
      local warm_ms = (now() - started) / 1e6
      if index > 100 then
        table.insert(run_result.native_ms, native_ms)
        table.insert(run_result.warm_ms, warm_ms)
      end
    end

    local lines = {}
    local expected = {}
    for index = 1, 1000 do
      lines[index] = "line " .. index .. " sample text"
      expected[index] = lines[index]:upper()
    end

    for _ = 1, 100 do
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      local changedtick = vim.api.nvim_buf_get_changedtick(0)
      started = now()
      vim.cmd("BunvimBenchmarkUppercase")
      assert(vim.wait(5000, function()
        return vim.api.nvim_buf_get_changedtick(0) ~= changedtick
      end))
      assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), expected))
      table.insert(run_result.edit_ms, (now() - started) / 1e6)
    end

    started = now()
    for _ = 1, 1000 do
      vim.api.nvim_exec_autocmds("User", { pattern = "BunvimBenchmarkEvent" })
    end

    assert(call("benchmark", "events") == 1000)
    assert(vim.wait(5000, function()
      return bunvim.status().pending == 0
    end))
    run_result.event_burst_ms = (now() - started) / 1e6
    local idle_before = read_process(status.pid)
    await(function(done)
      vim.defer_fn(function()
        done()
      end, 300)
    end)
    local idle_after = read_process(status.pid)
    run_result.idle_cpu_ticks = idle_after.cpu_ticks - idle_before.cpu_ticks
    run_result.host = idle_after
    run_result.native_summary = summarize(run_result.native_ms)
    run_result.warm_summary = summarize(run_result.warm_ms)
    run_result.edit_summary = summarize(run_result.edit_ms)
    await(function(done)
      bunvim.stop({ on_complete = done })
    end)
    assert(vim.fn.isdirectory("/proc/" .. status.pid) == 0, "host survived shutdown")
    table.insert(result.runs, run_result)
  end

  if vim.env.BUNVIM_SUSTAINED == "1" then
    await(function(done)
      bunvim.unload("benchmark", { on_complete = done })
    end)
    result.sustained = run_sustained()
  end

  return result
end

local ok, result = xpcall(run, debug.traceback)
bunvim.stop()
if not ok then
  io.stderr:write(tostring(result) .. "\n")
  vim.cmd("cquit 1")
end

io.stdout:write(vim.json.encode(result) .. "\n")
vim.cmd("qa!")

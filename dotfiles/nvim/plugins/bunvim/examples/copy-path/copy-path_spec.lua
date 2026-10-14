local directory = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
vim.opt.runtimepath:prepend(directory .. "/../..")
local bunvim = require("bunvim")

local await = function(start)
  local is_done, failure = false, nil
  start(function(err)
    failure, is_done = err, true
  end)
  assert(
    vim.wait(5000, function()
      return is_done
    end),
    "Copy path callback missing"
  )
  assert(not failure, failure)
end

local run = function()
  local copied, register_type = {}, "v"
  vim.g.clipboard = {
    name = "Bunvim test clipboard",
    copy = {
      ["+"] = function(lines, kind)
        copied, register_type = lines, kind
      end,
    },
    paste = {
      ["+"] = function()
        return { copied, register_type }
      end,
    },
  }
  local messages = {}
  vim.notify = function(message, level)
    table.insert(messages, { text = message, level = level })
  end
  await(function(done)
    bunvim.load("copy-path", { path = directory .. "/index.ts", on_complete = done })
  end)

  local run_command = function()
    vim.cmd("CopyFilePath")
    assert(vim.wait(5000, function()
      return bunvim.status().pending == 0
    end))
  end

  local source = vim.api.nvim_get_current_buf()
  local path = vim.fn.tempname() .. " sample.json"
  vim.api.nvim_buf_set_name(source, path)
  local other = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(other, path .. ".other")
  local get_name = vim.api.nvim_buf_get_name
  vim.api.nvim_buf_get_name = function(buffer)
    local name = get_name(buffer)
    vim.api.nvim_set_current_buf(other)
    return name
  end
  run_command()
  vim.api.nvim_buf_get_name = get_name
  assert(vim.deep_equal(copied, { path }))
  assert(register_type == "v")
  assert(messages[#messages].text == "Copied " .. path)

  vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
  run_command()
  assert(messages[#messages].text:find("This buffer has no file path", 1, true))
  assert(messages[#messages].level == vim.log.levels.ERROR)
  assert(vim.deep_equal(copied, { path }))

  vim.api.nvim_set_current_buf(source)
  vim.g.loaded_clipboard_provider = 1
  assert(vim.fn.has("clipboard") == 0)
  run_command()
  assert(messages[#messages].text:find("No clipboard provider is available", 1, true))
  assert(vim.deep_equal(copied, { path }))
  await(function(done)
    bunvim.unload("copy-path", { on_complete = done })
  end)
  assert(vim.fn.exists(":CopyFilePath") == 0)
  await(function(done)
    bunvim.stop({ on_complete = done })
  end)
end

local ok, failure = xpcall(run, debug.traceback)
bunvim.stop()
if not ok then
  io.stderr:write(tostring(failure) .. "\n" .. table.concat(bunvim.logs(), "\n") .. "\n")
  vim.cmd("cquit 1")
end

print("Copy path passed")
vim.cmd("qa!")

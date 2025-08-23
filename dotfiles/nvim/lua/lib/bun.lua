local M = {}

local function bunvim_call(plugin, method, ...)
  -- try to use the autoload
  if vim.fn.exists("*bunvim#call") == 1 then return vim.fn["bunvim#call"](plugin, method, ...) end

  -- fallback: call Bun directly
  local config_dir = vim.fn.stdpath("config")
  local script = config_dir .. "/plugins/bunvim/src/runner.ts"
  if vim.fn.executable("bun") == 0 then error("Bun is not installed. Please install from https://bun.sh") end
  if vim.fn.filereadable(script) == 0 then error("Bunvim runner not found at: " .. script) end
  local args = {
    plugin = plugin,
    method = method,
    args = { ... },
  }

  -- exec
  local tmpfile = vim.fn.tempname() .. ".json"
  vim.fn.writefile({ vim.fn.json_encode(args) }, tmpfile)
  local cmd = "bun run " .. vim.fn.shellescape(script) .. " " .. vim.fn.shellescape(tmpfile)
  local output = vim.fn.system(cmd)
  vim.fn.delete(tmpfile)
  local ok, result = pcall(vim.fn.json_decode, output)
  if not ok then error("Bunvim: Failed to parse response: " .. output) end
  if result.error then error("Bunvim error: " .. result.error) end
  return result.result
end

M.reload = function()
  vim.cmd("BunvimRestart")
  return "Reloading..."
end

M.status = function()
  local job_id = vim.g.bunvim_job_id
  if job_id and job_id > 0 then
    return { running = true, job_id = job_id }
  else
    return { running = false }
  end
end

setmetatable(M, {
  __index = function(t, plugin_name)
    local plugin = {}
    setmetatable(plugin, {
      __index = function(_, method_name)
        return function(...)
          return bunvim_call(plugin_name, method_name, ...)
        end
      end,
    })
    rawset(t, plugin_name, plugin)
    return plugin
  end,
})

return M

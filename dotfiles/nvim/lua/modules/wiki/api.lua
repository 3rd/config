local M = {}

local wiki_root = lib.path.resolve(lib.env.dirs.home, "brain", "wiki")
local system_options = {
  text = true,
  env = {
    WIKI_ROOT = wiki_root,
    TASK_ROOT = wiki_root,
  },
}

local format_error = function(result)
  local stderr = vim.trim(result.stderr or "")
  if stderr ~= "" then return stderr end
  return "core wiki exited with code " .. result.code
end

local run_core_wiki = function(arguments)
  local command = { "core", "wiki" }
  vim.list_extend(command, arguments)

  local ok, process = pcall(vim.system, command, system_options)
  if not ok then return nil, tostring(process) end

  local result = process:wait()
  if result.code ~= 0 then return nil, format_error(result) end
  return result.stdout or ""
end

local parse_entries = function(stdout)
  local entries = {}
  for _, line in ipairs(vim.split(stdout, "\n", { plain = true, trimempty = true })) do
    local entry = vim.trim(line)
    if entry ~= "" then entries[#entries + 1] = entry end
  end
  table.sort(entries)
  return entries
end

M.list_nodes = function()
  local stdout, list_error = run_core_wiki({ "ls" })
  if not stdout then return nil, list_error end
  return parse_entries(stdout)
end

M.list_projects = function()
  local stdout, list_error = run_core_wiki({ "ls", "--type", "project" })
  if not stdout then return nil, list_error end
  return parse_entries(stdout)
end

M.list_nodes_async = function(callback)
  local command = { "core", "wiki", "ls" }
  local cancelled = false
  local process

  local complete = function(entries, list_error)
    vim.schedule(function()
      if not cancelled then callback(entries, list_error) end
    end)
  end

  local ok, result = pcall(vim.system, command, system_options, function(system_result)
    if system_result.code ~= 0 then
      complete(nil, format_error(system_result))
      return
    end
    complete(parse_entries(system_result.stdout or ""))
  end)

  if ok then
    process = result
  else
    complete(nil, tostring(result))
  end

  return function()
    cancelled = true
    if process then pcall(process.kill, process, 15) end
  end
end

M.resolve_node = function(id)
  local stdout, resolve_error = run_core_wiki({ "resolve", id })
  if not stdout then return nil, resolve_error end

  local path = vim.trim(stdout)
  if path == "" then return nil, "core wiki returned an empty path" end
  return path
end

return M

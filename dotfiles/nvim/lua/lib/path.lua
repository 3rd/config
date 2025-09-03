local cwd = function()
  return vim.loop.cwd()
end

---@vararg string|string[]
---@return string
local resolve = function(...)
  local args = { ... }
  local path = table.concat(args, "/")
  return vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
end

local resolve_config = function(...)
  local args = { vim.fn.stdpath("config"), ... }
  return resolve(unpack(args))
end

local resolve_relative = function(path)
  return vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(path), ":."))
end

local cwd_is_git_repo = function()
  local status = vim.fn.system("git status")
  return vim.v.shell_error == 0 and status ~= ""
end

local default_find_root_patterns = {
  ".root",
  "package.json",
  "go.mod",
}
local find_root = function(patterns)
  patterns = patterns or default_find_root_patterns
  local path = vim.fs.dirname(lib.buffer.current.get_path())
  if path == "." then path = vim.loop.cwd() or "" end
  if path == "" then return nil end
  local match = vim.fs.find(default_find_root_patterns, {
    path = path,
    upward = true,
    stop = vim.loop.os_homedir(),
  })[1] or nil
  if not match then return end
  return vim.fs.dirname(match) .. "/"
end

---@vararg string|string[]
---@return boolean
local root_has = function(...)
  local root_path = find_root()
  if not root_path then return false end
  for _, path in ipairs({ ... }) do
    if vim.fn.filereadable(resolve(root_path, path)) == 1 then return true end
  end
  return false
end

return {
  cwd = cwd,
  resolve = resolve,
  resolve_relative = resolve_relative,
  resolve_config = resolve_config,
  cwd_is_git_repo = cwd_is_git_repo,
  root_has = root_has,
  find_root = find_root,
}

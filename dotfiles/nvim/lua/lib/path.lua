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

---@vararg string|string[]
---@return boolean
local root_has = function(...)
  local root_path = cwd()
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
}

local module = {}

module.resolve = function(path)
  return vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
end

module.resolve_relative = function(path)
  return vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(path), ":."))
end

module.exists = function(path)
  local resolved_path = module.resolve(path)
  local ok, err, code = os.rename(resolved_path, resolved_path)
  if ok then
    return ok, err
  end
  return code == 13, err
end

module.is_directory = function(path)
  return module.exists(path .. "/")
end

module.is_file = function(path)
  return module.exists(path) and not module.is_directory(path)
end

module.is_readable_file = function(path)
  return vim.fn.filereadable(module.resolve(path)) == 1
end

module.is_writable_file = function(path)
  return vim.fn.filewritable(module.resolve(path)) == 1
end

module.is_executable_file = function(path)
  return vim.fn.executable(path) == 1
end

module.cwd_is_git_repo = function()
  local rev = io.popen("git rev-parse --git-dir 2> /dev/null"):read("*all")
  return #rev ~= 0
end

return module

local cwd = function()
  return vim.loop.cwd()
end

local resolve = function(...)
  local args = { ... }
  local path = table.concat(args, "/")
  return vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
end

local resolve_relative = function(path)
  return vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(path), ":."))
end

return {
  cwd = cwd,
  resolve = resolve,
  resolve_relative = resolve_relative,
}

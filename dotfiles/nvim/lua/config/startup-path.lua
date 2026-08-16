local directories_with_main = { "work" }

local resolve_startup_paths = function(arguments)
  return vim.tbl_map(function(path)
    if not vim.tbl_contains(directories_with_main, path) or vim.fn.isdirectory(path) ~= 1 then return path end
    return vim.fs.joinpath(path, "main")
  end, arguments)
end

local setup = function()
  local arguments = vim.fn.argv()
  local startup_paths = resolve_startup_paths(arguments)
  if vim.deep_equal(startup_paths, arguments) then return end

  vim.cmd.args({ args = startup_paths })
end

return {
  setup = setup,
}

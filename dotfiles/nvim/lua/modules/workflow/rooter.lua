local get_root = function()
  return lib.path.find_root()
end

local get_cwd = function()
  local target = get_root()
  if target then return target end

  local path = lib.buffer.current.get_path()
  if type(path) ~= "string" or path == "" then return vim.uv.cwd() end

  local parent = vim.fs.dirname(path)
  if not parent or parent == "." or parent == "" then return vim.uv.cwd() end

  return vim.fn.fnamemodify(parent, ":p")
end

local sync_cwd = function()
  local target = get_root()
  if not target then return nil end
  if target == vim.uv.cwd() then return target end

  vim.fn.chdir(target)
  return target
end

local setup = function()
  local group = vim.api.nvim_create_augroup("rooter", {})
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function()
      if vim.g.rooter_done then return end
      local target = sync_cwd()
      if not target then return end
      vim.g.rooter_done = true
      pcall(vim.api.nvim_clear_autocmds, { group = group })
    end,
  })
end

return lib.module.create({
  name = "workflow/rooter",
  hosts = "*",
  setup = setup,
  exports = {
    get_root = get_root,
    get_cwd = get_cwd,
    sync_cwd = sync_cwd,
  },
})

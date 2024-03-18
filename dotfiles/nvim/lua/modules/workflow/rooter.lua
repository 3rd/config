local patterns = {
  ".root",
  ".git",
}

local find_root = function()
  local path = vim.fs.dirname(lib.buffer.current.get_path())
  if path == "." then path = vim.loop.cwd() or "" end
  if path == "" then return nil end
  return vim.fs.find(patterns, {
    path = path,
    upward = true,
    stop = vim.loop.os_homedir(),
  })[1] or nil
end

local setup = function()
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("rooter", {}),
    callback = function()
      local root = find_root()
      if not root then return end
      local root_path = vim.fs.dirname(root) .. "/"
      vim.fn.chdir(root_path)
    end,
  })
end

return lib.module.create({
  name = "workflow/rooter",
  setup = setup,
})

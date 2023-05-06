local patterns = {
  ".root",
  ".git",
}

local find_root = function()
  local buffer_path = lib.buffer.current.get_path()
  local path = vim.fs.dirname(buffer_path)
  return vim.fs.find(patterns, {
    path = path,
    upward = true,
    stop = vim.loop.os_homedir(),
  })[1] or path
end

local setup = function()
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("rooter", {}),
    callback = function()
      -- if lib.buffer.current.get_name() == "" then return end
      local root = find_root()
      if not root then return end
      vim.fn.chdir(vim.fs.dirname(root))
    end,
  })
end

return lib.module.create({
  name = "workflow/rooter",
  setup = setup,
})

local function get_view_file_path()
  local view_dir = vim.fn.eval("&viewdir")
  local buf_name = vim.api.nvim_buf_get_name(0)
  local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE")
  buf_name = buf_name:gsub("^" .. home_dir, "~")
  local view_file_path = view_dir .. "/" .. buf_name:gsub("/", "=+") .. "="
  return view_file_path
end

local reset_folds = function(internal)
  local path = get_view_file_path()
  -- log(path)
  if lib.fs.exists(path) then
    vim.cmd("normal! zX")
    os.remove(path)
    vim.cmd("silent! loadview")
    if not internal then
      vim.notify("View file has been nuked.", vim.log.levels.INFO, { title = "Reset view file" })
      log(path)
      vim.cmd("noa q")
    end
  else
    if not internal then vim.api.nvim_err_writeln("Cannot find view file at: " .. path) end
  end
end

return lib.module.create({
  name = "workflow/reset-view",
  hosts = "*",
  actions = {
    { "n", "Reset view & folds", reset_folds },
  },
  exports = {
    reset_folds = function()
      reset_folds(true)
    end,
  },
})

local function get_view_file_path()
  local view_dir = vim.fn.eval("&viewdir")
  local buf_name = vim.api.nvim_buf_get_name(0)
  local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE")
  buf_name = buf_name:gsub("^" .. home_dir, "~")
  local view_file_path = view_dir .. "/" .. buf_name:gsub("/", "=+") .. "="
  return view_file_path
end

local reset_folds = function()
  local path = get_view_file_path()
  log(lib.fs.exists(path))
  if lib.fs.exists(path) then
    vim.cmd("normal! zR")
    os.remove(path)
    vim.notify("View file has been nuked.", vim.log.levels.INFO, { title = "Reset view file" })
  else
    vim.api.nvim_err_writeln("Cannot find view file at: " .. path)
  end
end

return lib.module.create({
  name = "workflow/reset-folds",
  actions = {
    { "n", "Reset view & folds", reset_folds },
  },
})

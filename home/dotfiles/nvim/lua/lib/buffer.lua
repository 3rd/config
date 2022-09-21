local module = {
  current = {},
}

module.get_name = function(handle)
  return vim.api.nvim_buf_get_name(handle)
end

module.set_name = function(handle, value)
  vim.api.nvim_buf_set_name(handle, value)
end

module.get_option = function(handle, key)
  return vim.api.nvim_buf_get_option(handle, key)
end

module.set_option = function(handle, key, value)
  vim.api.nvim_buf_set_option(handle, key, value)
end

module.get_lines = function(handle, start, _end)
  return vim.api.nvim_buf_get_lines(handle, start or 0, _end or -1, true)
end

module.current_get_handle = function()
  return vim.api.nvim_get_current_buf()
end

module.current.get_name = function()
  return module.get_name(0)
end

module.current.get_shortname = function()
  return vim.fn.expand("%:t:r")
end

module.current.get_path = function()
  return vim.fn.expand("%:p")
end

module.current.get_filetype = function()
  return vim.api.nvim_eval("&ft")
end

module.current.set_filetype = function(value)
  vim.bo.filetype = value
end

module.current.get_extension = function()
  return vim.fn.expand("%e")
end

module.current.get_directory = function()
  return vim.fn.expand("%:p:h")
end

module.current.get_path_without_extension = function()
  return vim.fn.expand("%:p:r")
end

module.current.get_text = function()
  return vim.api.nvim_eval([[join(getline(1, '$'), "\n")]])
end

module.current.get_selected_text = function(context)
  local first = vim.fn.getpos("'<")[2] - 1
  local last = vim.fn.getpos("'>")[2]
  if context and context > 0 then
    first = first - context
    last = last + context
  end
  local lines = vim.api.nvim_buf_get_lines(0, first, last, false)
  local text = vim.fn.join(lines, "\n")
  return text
end

module.current.get_current_line = function()
  return vim.api.nvim_get_current_line()
end

module.current.set_current_line = function(value)
  vim.api.nvim_set_current_line(value)
end

module.current.get_current_word = function()
  return vim.fn.expand("<cword>")
end

module.current.get_lines = function(start, _end)
  return module.get_lines(0, start, _end)
end

return module

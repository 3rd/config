local handle_close = function()
  local buffers = vim.api.nvim_list_bufs()
  local file_buffers = {}
  local file_buffers_count = 0
  for _, buffer_id in pairs(buffers) do
    local buffer_is_valid = vim.api.nvim_buf_is_valid(buffer_id)
    local buffer_is_listed = vim.fn.getbufvar(buffer_id, "&buflisted") == 1
    local buffer_is_terminal = vim.fn.getbufvar(buffer_id, "&buftype")
      == "terminal"
    local buffer_is_file = buffer_is_valid
      and buffer_is_listed
      and not buffer_is_terminal
    if buffer_is_file then
      file_buffers_count = file_buffers_count + 1
      file_buffers[file_buffers_count] = buffer_id
    end
  end
  local current_buffer_id = vim.api.nvim_get_current_buf()
  local buffer_index = nil
  for index, buffer_id in ipairs(file_buffers) do
    if buffer_id == current_buffer_id then
      buffer_index = index
      break
    end
  end
  if buffer_index == nil then
    buffer_index = 0
  end
  local previous_buffer_index = (buffer_index - 1) % (file_buffers_count + 1)
  if previous_buffer_index == 0 then
    previous_buffer_index = file_buffers_count
  end
  local previous_buffer = file_buffers[file_buffers_count - 1]
  if previous_buffer then
    vim.cmd(string.format("buffer %d", previous_buffer))
  end
  vim.cmd(string.format("bdelete %d", current_buffer_id))
end

return require("lib").module.create({
  name = "workflow/buffer-close",
  mappings = {
    {
      "n",
      "<C-w>",
      ":lua require('modules/workflow/buffer-close').export.handle_close()<CR>",
    },
  },
  export = {
    handle_close = handle_close,
  },
})

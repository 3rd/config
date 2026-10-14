local M = {}

M.read = function(bufnr, start_row, end_row)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local range_end = end_row == -1 and line_count or end_row
  return {
    buffer = bufnr,
    changedtick = vim.api.nvim_buf_get_changedtick(bufnr),
    start = start_row,
    ["end"] = range_end,
    lines = vim.api.nvim_buf_get_lines(bufnr, start_row, range_end, true),
  }
end

M.replace = function(snapshot, lines)
  if not vim.api.nvim_buf_is_loaded(snapshot.buffer) then error("Buffer is no longer loaded") end
  if vim.api.nvim_buf_get_changedtick(snapshot.buffer) ~= snapshot.changedtick then
    error("Buffer changed while the operation was running")
  end

  vim.api.nvim_buf_set_lines(snapshot.buffer, snapshot.start, snapshot["end"], true, lines)
end

M.apply_text_edits = function(snapshot, edits)
  local is_current_target = vim.api.nvim_get_current_buf() == snapshot.buffer
    and vim.api.nvim_get_current_win() == snapshot.window
    and vim.bo[snapshot.buffer].filetype == snapshot.filetype
    and vim.api.nvim_buf_get_changedtick(snapshot.buffer) == snapshot.changedtick
    and vim.deep_equal(vim.api.nvim_win_get_cursor(snapshot.window), snapshot.position)
  if not is_current_target then return false end

  vim.lsp.util.apply_text_edits(edits, snapshot.buffer, "utf-8")
  return true
end

return M

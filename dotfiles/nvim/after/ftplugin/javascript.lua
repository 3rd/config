--https://www.youtube.com/watch?v=_m7amJZpQQ8
local function add_async()
  vim.api.nvim_feedkeys("t", "n", true)
  local buffer = vim.fn.bufnr()

  local text_before_cursor = vim.fn.getline("."):sub(vim.fn.col(".") - 4, vim.fn.col(".") - 1)
  if text_before_cursor ~= "awai" then return end

  -- ignore_injections = false makes this snippet work in filetypes where JS is injected
  -- into other languages
  local current_node = vim.treesitter.get_node({ ignore_injections = false })
  if not current_node then return end
  local function_node = lib.ts.find_parent(current_node, { "arrow_function", "function_declaration", "function" })
  if not function_node then return end

  local function_text = vim.treesitter.get_node_text(function_node, 0)
  if vim.startswith(function_text, "async") then return end

  local start_row, start_col = function_node:start()
  vim.api.nvim_buf_set_text(buffer, start_row, start_col, start_row, start_col, { "async " })
end
vim.keymap.set("i", "t", add_async, { buffer = true })

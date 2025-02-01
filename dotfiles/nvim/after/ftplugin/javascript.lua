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

local function toggle_test_only()
  local current_node = vim.treesitter.get_node()
  if not current_node then return end

  local function is_it_call(node)
    if node:type() ~= "call_expression" then return false end
    local func_name_node = node:child(0)
    if not func_name_node then return false end
    local func_text = vim.treesitter.get_node_text(func_name_node, 0)
    return func_text == "it" or func_text == "it.only"
  end

  -- find parent it call
  local it_node = current_node
  while it_node do
    if is_it_call(it_node) then break end
    it_node = it_node:parent()
  end
  if not it_node then return end

  -- get function name and pos
  local func_name_node = it_node:child(0)
  if not func_name_node then return end
  local func_text = vim.treesitter.get_node_text(func_name_node, 0)
  local buffer = vim.fn.bufnr()
  local start_row, start_col = func_name_node:start()
  local end_row, end_col = func_name_node:end_()

  -- toggle
  if func_text == "it" then
    vim.api.nvim_buf_set_text(buffer, start_row, start_col, end_row, end_col, { "it.only" })
  elseif func_text == "it.only" then
    vim.api.nvim_buf_set_text(buffer, start_row, start_col, end_row, end_col, { "it" })
  end
end
vim.keymap.set("n", "<leader>to", toggle_test_only, { buffer = true, desc = "Toggle test.only" })

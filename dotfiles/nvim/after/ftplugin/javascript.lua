--https://www.youtube.com/watch?v=_m7amJZpQQ8
local function add_async()
  vim.api.nvim_feedkeys("t", "n", true)
  local buffer = vim.api.nvim_get_current_buf()

  -- wait for “awai”
  local col = vim.fn.col(".")
  if vim.fn.getline("."):sub(col - 4, col - 1) ~= "awai" then return end

  -- get node at cursor
  local node = vim.treesitter.get_node({ ignore_injections = false })
  if not node then return end

  -- climb the tree until the *first* function‑like ancestor
  local TYPES = {
    arrow_function = true,
    function_declaration = true,
    ["function"] = true,
  }
  while node and not TYPES[node:type()] do
    node = node:parent()
  end
  if not node then return end -- bail if not inside a function

  -- check if already async
  local fn_text = vim.treesitter.get_node_text(node, buffer)
  if fn_text:sub(1, 5) == "async" then return end

  -- insert async
  local start_row, start_col = node:start()
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

-- simple bookmarking system
-- <leader><num> to go to a bookmark
-- <leader><leader><num> to set a bookmark

local config = {
  spear_count = 6,
  default_icon = "",
  icons = { "➊", "➋", "➌", "➍", "➎", "➏" },
}

---@type table<number, {bufnr: number, row: number, col: number}>
local mappings = {}

for i = 1, config.spear_count do
  local name = string.format("SpearBookmark%s", i)
  vim.fn.sign_define(name, {
    text = config.icons[i] or config.default_icon,
    texthl = "LineNr",
    culhl = "CursorLineSign",
    -- linehl = "",
    -- numhl = "",
  })
end

local remove_bookmark = function(index)
  if not mappings[index] then return end
  local mapping = mappings[index]
  local sign = string.format("SpearBookmark%s", index)
  vim.fn.sign_unplace(sign, { buffer = mapping.bufnr })
  mappings[index] = nil
end

local add_bookmark = function(index)
  local bufnr = vim.api.nvim_get_current_buf()
  local winnr = vim.api.nvim_get_current_win()
  local row, col = unpack(vim.api.nvim_win_get_cursor(winnr))
  local prev_mapping = mappings[index]
  remove_bookmark(index)
  if prev_mapping and prev_mapping.bufnr == bufnr and prev_mapping.row == row and prev_mapping.col == col then
    return
  end
  mappings[index] = { bufnr = bufnr, row = row, col = col }
  local sign = string.format("SpearBookmark%s", index)
  vim.fn.sign_place(0, sign, sign, bufnr, { lnum = row })
end

local remove_bookmark_for_buf = function(bufnr)
  for i = 1, config.spear_count do
    local mapping = mappings[i]
    if mapping and mapping.bufnr == bufnr then remove_bookmark(i) end
  end
end

local navigate = function(index)
  local mapping = mappings[index]
  if mapping then
    local current_bufnr = vim.api.nvim_get_current_buf()
    if current_bufnr == mapping.bufnr then
      vim.api.nvim_win_set_cursor(0, { mapping.row, mapping.col })
    else
      vim.api.nvim_set_current_buf(mapping.bufnr)
    end
  end
end

local setup = function()
  -- mappings
  for i = 1, config.spear_count do
    local key = string.format("<leader>%s", i)
    vim.keymap.set("n", key, function()
      navigate(i)
    end, {
      noremap = true,
      silent = true,
      desc = string.format("Navigate to %s", i),
    })
  end
  for i = 1, config.spear_count do
    local key = string.format("<leader><leader>%s", i)
    vim.keymap.set("n", key, function()
      add_bookmark(i)
    end, {
      noremap = true,
      silent = true,
      desc = string.format("Set bookmark %s", i),
    })
  end

  -- autocommands
  vim.api.nvim_create_autocmd("BufDelete", {
    callback = function(event)
      remove_bookmark_for_buf(event.buf)
    end,
  })
end

return {
  setup = setup,
}

local history = {}

local setup = function()
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = vim.api.nvim_create_augroup("buffer-alternate", {}),
    callback = function()
      local winid = vim.api.nvim_get_current_win()
      local bufnr = vim.api.nvim_get_current_buf()
      if not history[winid] then
        history[winid] = { bufnr }
      else
        table.insert(history[winid], bufnr)
      end
    end,
  })
end

local get_previous_buffer = function(opts)
  opts = opts or { pop = false }
  local current_winid = vim.api.nvim_get_current_win()
  local current_bufnr = vim.api.nvim_win_get_buf(current_winid)

  -- default: window history
  local window_history = history[current_winid]
  if not window_history then return nil end
  for i = #window_history - 1, 1, -1 do
    local bufnr = window_history[i]
    if bufnr ~= current_bufnr then
      local is_valid = vim.api.nvim_buf_is_valid(bufnr)
      -- local is_loaded = vim.api.nvim_buf_is_loaded(bufnr)
      local info = vim.fn.getbufinfo(bufnr)
      -- local is_closed = #info == 1 and info[1].lastused ~= 0 and not is_loaded
      local is_listed = #info == 1 and info[1].listed == 1
      local is_noname = #info == 1 and info[1].name == ""
      local is_in_floating_window = false
      if #info == 1 then
        for _, window_id in ipairs(info[1].windows) do
          local window = vim.api.nvim_win_get_config(window_id)
          if window.relative ~= "" then is_in_floating_window = true end
        end
      end

      if is_valid and (is_listed or (not is_in_floating_window and not is_noname)) then
        if opts.pop then table.remove(window_history, i) end
        -- log("from history", bufnr)
        return bufnr
      end
    end
  end

  -- fallback: last used
  local buffers = vim.fn.getbufinfo() -- maybe spin-off with { buflisted = true }?
  table.sort(buffers, function(a, b)
    return a.loaded and not b.loaded or a.lastused > b.lastused -- { bufnr, lastused, windows, variables }
  end)
  for _, buffer in ipairs(buffers) do
    local bufnr = buffer.bufnr
    if bufnr ~= current_bufnr then
      local is_valid = vim.api.nvim_buf_is_valid(bufnr)
      -- local is_loaded = vim.api.nvim_buf_is_loaded(bufnr)
      local info = vim.fn.getbufinfo(bufnr)
      -- local is_closed = #info == 1 and info[1].lastused ~= 0 and not is_loaded
      local is_listed = #info == 1 and info[1].listed == 1
      local is_noname = #info == 1 and info[1].name == ""
      local is_in_floating_window = false
      if #info == 1 then
        for _, window_id in ipairs(info[1].windows) do
          local window = vim.api.nvim_win_get_config(window_id)
          if window.relative ~= "" then is_in_floating_window = true end
        end
      end

      if is_valid and (is_listed or (not is_in_floating_window and not is_noname)) then
        -- log("from history", bufnr)
        return bufnr
      end
    end
  end

  return nil
end

-- smarter "<c-^>"
local handle_alternate = function()
  local previous_buffer = get_previous_buffer()
  if previous_buffer then
    vim.api.nvim_set_current_buf(previous_buffer)
    return
  end
  vim.cmd("normal! <c-^>")
end

-- smarter close
local handle_close = function()
  local current_bufnr = vim.api.nvim_get_current_buf()
  local current_winid = vim.api.nvim_get_current_win()
  ---@diagnostic disable-next-line: param-type-mismatch
  local info = vim.fn.getbufinfo(current_bufnr)
  local previous_bufnr = get_previous_buffer({ pop = true })

  if previous_bufnr then
    -- log("switch", previous_buffer)
    vim.api.nvim_set_current_buf(previous_bufnr)
  end

  local is_open_in_other_windows = false
  if #info == 1 then
    for _, window_id in ipairs(info[1].windows) do
      if window_id ~= current_winid then is_open_in_other_windows = true end
    end
  end

  if not is_open_in_other_windows then
    vim.cmd(string.format("bwipeout! %d", current_bufnr))
    return
  end
end

return lib.module.create({
  name = "workflow/buffer",
  setup = setup,
  mappings = {
    { "n", "<bs>", handle_alternate, "Switch to alternate buffer" },
    { "n", "<c-w>", handle_close, "Close buffer" },
  },
})

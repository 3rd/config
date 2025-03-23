--- awesomeness from https://www.youtube.com/watch?v=rerTvidyz-0

---@class TermOpenOpts
---@field cmd string

---@param opts TermOpenOpts
local open = function(opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local width = math.ceil(vim.o.columns * 0.85)
  local height = math.ceil(vim.o.lines * 0.85)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.ceil((vim.o.lines - height) / 2),
    col = math.ceil((vim.o.columns - width) / 2),
    style = "minimal",
  })
  vim.api.nvim_set_current_win(win)

  vim.fn.termopen({ opts.cmd }, {
    on_exit = function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end,
  })

  vim.cmd.startinsert()
end

return {
  open = open,
}

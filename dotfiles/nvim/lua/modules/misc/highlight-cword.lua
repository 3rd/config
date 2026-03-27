local api = vim.api

local DEFAULT_FILETYPE_EXCLUDES = {
  dashboard = true,
  help = true,
  lazy = true,
  markdown = true,
  syslang = true,
}
local DEFAULT_BUFTYPE_EXCLUDES = {
  nofile = true,
  prompt = true,
  terminal = true,
}

local window_state = {}
local refresh_scheduled = false
local pending_winid = nil

local get_window_state = function(winid)
  local state = window_state[winid]
  if state then return state end

  state = {
    current_match_id = nil,
    other_match_id = nil,
    key = nil,
  }
  window_state[winid] = state
  return state
end

local clear_pending_refresh = function()
  pending_winid = nil
end

local clear_window_matches_in_context = function(state)
  if state.other_match_id then
    pcall(vim.fn.matchdelete, state.other_match_id)
    state.other_match_id = nil
  end
  if state.current_match_id then
    pcall(vim.fn.matchdelete, state.current_match_id)
    state.current_match_id = nil
  end
  state.key = nil
end

local clear_window_matches = function(winid, opts)
  opts = opts or {}
  local state = window_state[winid]
  if not state then return end

  if api.nvim_win_is_valid(winid) then
    api.nvim_win_call(winid, function()
      clear_window_matches_in_context(state)
    end)
  end

  if opts.drop_state then window_state[winid] = nil end
end

local is_normal_mode = function()
  return vim.startswith(api.nvim_get_mode().mode, "n")
end

local should_skip_buffer = function(bufnr, filetype_excludes)
  local filetype = vim.bo[bufnr].filetype
  if filetype_excludes[filetype] then return true end

  local buftype = vim.bo[bufnr].buftype
  if DEFAULT_BUFTYPE_EXCLUDES[buftype] then return true end

  return false
end

local build_pattern = function(word)
  if word == "" then return nil end
  return ([[\V\<%s\>]]):format(word:gsub([[\]], [[\\]]))
end

local collect_positions = function(bufnr, top, bottom, cursor_line, cursor_col0, word)
  local pattern = build_pattern(word)
  if not pattern then return {}, nil end

  local matches = vim.fn.matchbufline(bufnr, pattern, top, bottom)
  if vim.tbl_isempty(matches) then return {}, nil end

  local current_position = nil
  local other_positions = {}

  for _, match in ipairs(matches) do
    local start_col0 = match.byteidx
    local length = #(match.text or word)
    local pos = { match.lnum, start_col0 + 1, length }
    local cursor_is_inside = match.lnum == cursor_line
      and cursor_col0 >= start_col0
      and cursor_col0 < start_col0 + length

    if cursor_is_inside and not current_position then
      current_position = pos
    else
      table.insert(other_positions, pos)
    end
  end

  return other_positions, current_position
end

local build_state_key = function(bufnr, changedtick, top, bottom, word, current_position, other_count)
  return table.concat({
    bufnr,
    changedtick,
    top,
    bottom,
    word,
    current_position and current_position[1] or 0,
    current_position and current_position[2] or 0,
    other_count,
  }, ":")
end

local refresh_window = function(winid, filetype_excludes)
  if not winid or not api.nvim_win_is_valid(winid) then return end
  if winid ~= api.nvim_get_current_win() then
    clear_window_matches(winid)
    return
  end

  local bufnr = api.nvim_win_get_buf(winid)
  if should_skip_buffer(bufnr, filetype_excludes) or not is_normal_mode() then
    clear_window_matches(winid)
    return
  end

  api.nvim_win_call(winid, function()
    local state = get_window_state(winid)
    local word = vim.fn.expand("<cword>")
    if word == nil or word == "" then
      clear_window_matches_in_context(state)
      return
    end

    local changedtick = api.nvim_buf_get_changedtick(bufnr)
    local top = vim.fn.line("w0")
    local bottom = vim.fn.line("w$")
    local cursor = api.nvim_win_get_cursor(0)
    local cursor_line = cursor[1]
    local cursor_col0 = vim.fn.col(".") - 1
    local other_positions, current_position = collect_positions(bufnr, top, bottom, cursor_line, cursor_col0, word)
    local state_key = build_state_key(bufnr, changedtick, top, bottom, word, current_position, #other_positions)

    if state.key == state_key then return end

    clear_window_matches_in_context(state)
    if #other_positions == 0 and not current_position then return end

    if #other_positions > 0 then state.other_match_id = vim.fn.matchaddpos("CursorWord", other_positions, 10) end
    if current_position then
      state.current_match_id = vim.fn.matchaddpos("CursorWordCurrent", { current_position }, 11)
    end
    state.key = state_key
  end)
end

local schedule_refresh = function(winid, filetype_excludes)
  pending_winid = winid
  if refresh_scheduled then return end

  refresh_scheduled = true
  vim.schedule(function()
    local target_winid = pending_winid
    refresh_scheduled = false
    pending_winid = nil
    refresh_window(target_winid, filetype_excludes)
  end)
end

local setup = function()
  local filetype_excludes = vim.tbl_extend("force", {}, DEFAULT_FILETYPE_EXCLUDES)
  local augroup = api.nvim_create_augroup("highlight-cword", { clear = true })

  local schedule_current_window_refresh = function()
    schedule_refresh(api.nvim_get_current_win(), filetype_excludes)
  end

  api.nvim_create_autocmd(
    { "BufWinEnter", "CursorMoved", "InsertLeave", "TextChanged", "VimEnter", "WinEnter", "WinScrolled" },
    {
      group = augroup,
      callback = schedule_current_window_refresh,
    }
  )

  api.nvim_create_autocmd("InsertEnter", {
    group = augroup,
    callback = function()
      clear_pending_refresh()
      clear_window_matches(api.nvim_get_current_win())
    end,
  })

  api.nvim_create_autocmd("ModeChanged", {
    group = augroup,
    callback = function()
      local old_mode = vim.v.event.old_mode or ""
      local new_mode = vim.v.event.new_mode or ""
      local old_is_normal = vim.startswith(old_mode, "n")
      local new_is_normal = vim.startswith(new_mode, "n")

      if old_is_normal == new_is_normal then return end
      if new_is_normal then
        schedule_current_window_refresh()
        return
      end

      clear_pending_refresh()
      clear_window_matches(api.nvim_get_current_win())
    end,
  })

  api.nvim_create_autocmd("WinLeave", {
    group = augroup,
    callback = function()
      local winid = api.nvim_get_current_win()
      if pending_winid == winid then clear_pending_refresh() end
      clear_window_matches(winid)
    end,
  })

  api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    callback = function(args)
      local winid = tonumber(args.match)
      if not winid then return end
      if pending_winid == winid then clear_pending_refresh() end
      window_state[winid] = nil
    end,
  })
end

return lib.module.create({
  name = "highlight-cword",
  hosts = "*",
  setup = setup,
})

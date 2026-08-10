local get_file_buffer_path = function(bufnr)
  if vim.bo[bufnr].buftype ~= "" then return nil end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then return nil end

  return vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
end

local path_is_within_root = function(path, root)
  return path == root or vim.startswith(path, root .. "/")
end

local prepare_project_session = function(root)
  local state = {
    hidden = vim.o.hidden,
    buffer_listed = {},
    windows = {},
  }
  local project_buffer = nil

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local path = get_file_buffer_path(bufnr)
    if path and path_is_within_root(path, root) then
      project_buffer = project_buffer or bufnr
    elseif path then
      state.buffer_listed[bufnr] = vim.bo[bufnr].buflisted
      vim.bo[bufnr].buflisted = false
    end
  end

  if not project_buffer then return state end

  local project_path = vim.api.nvim_buf_get_name(project_buffer)
  vim.o.hidden = true

  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    local alternate_bufnr = vim.api.nvim_win_call(winid, function()
      return vim.fn.bufnr("#")
    end)
    local buffer_path = get_file_buffer_path(bufnr)
    local alternate_path = alternate_bufnr >= 0 and get_file_buffer_path(alternate_bufnr) or nil
    local buffer_is_external = buffer_path and not path_is_within_root(buffer_path, root)
    local alternate_is_external = alternate_path and not path_is_within_root(alternate_path, root)

    if buffer_is_external or alternate_is_external then
      state.windows[winid] = {
        bufnr = bufnr,
        alternate_path = alternate_path,
        view = vim.api.nvim_win_call(winid, vim.fn.winsaveview),
        buffer_changed = buffer_is_external,
        alternate_changed = alternate_is_external,
      }

      vim.api.nvim_win_call(winid, function()
        if buffer_is_external then vim.cmd("noautocmd keepalt buffer " .. project_buffer) end
        if alternate_is_external then vim.cmd("noautocmd balt " .. vim.fn.fnameescape(project_path)) end
      end)
    end
  end

  return state
end

local restore_project_session = function(state)
  for winid, window in pairs(state.windows) do
    if vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_call(winid, function()
        if window.buffer_changed and vim.api.nvim_buf_is_valid(window.bufnr) then
          vim.cmd("noautocmd keepalt buffer " .. window.bufnr)
          vim.fn.winrestview(window.view)
        end
        if window.alternate_changed then vim.cmd("noautocmd balt " .. vim.fn.fnameescape(window.alternate_path)) end
      end)
    end
  end

  for bufnr, listed in pairs(state.buffer_listed) do
    if vim.api.nvim_buf_is_valid(bufnr) then vim.bo[bufnr].buflisted = listed end
  end

  vim.o.hidden = state.hidden
end

local limit_sessions_to_project_root = function(autosession)
  local save_session = autosession.save_session

  autosession.save_session = function(...)
    local args = { ... }
    local arg_count = select("#", ...)
    local root = vim.fs.normalize(vim.fn.getcwd(-1, -1))
    local state = nil
    local results = nil
    local ok, save_error = xpcall(function()
      state = prepare_project_session(root)
      results = { save_session(unpack(args, 1, arg_count)) }
    end, debug.traceback)

    local restored, restore_error = xpcall(function()
      if state then restore_project_session(state) end
    end, debug.traceback)

    if not ok then error(save_error) end
    if not restored then error(restore_error) end
    return unpack(results)
  end
end

local setup_auto_session = function()
  local autosession = require("auto-session")
  autosession.setup({
    log_level = "error",
    auto_session_enabled = true,
    auto_save_enabled = true,
    auto_restore_enabled = true,
    auto_session_create_enabled = false,
    auto_session_enable_last_session = false,
    auto_session_root_dir = lib.env.dirs.vim.sessions .. "/",
    auto_session_suppress_dirs = { "~/", "~/Downloads", "~/Desktop" },
    silent_restore = true,
    cwd_change_handling = {
      restore_upcoming_session = false,
    },
    pre_save_cmds = {
      -- close floating windows
      function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local config = vim.api.nvim_win_get_config(win)
          if config.relative ~= "" then vim.api.nvim_win_close(win, false) end
        end
      end,
      -- close no-name buffers
      function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_get_name(buf) == "" then vim.api.nvim_buf_delete(buf, {}) end
        end
      end,
      -- close nvim-tree
      function()
        local ok, api = pcall(require, "nvim-tree.api")
        if ok then api.tree.close_in_all_tabs() end
      end,
    },
  })
  limit_sessions_to_project_root(autosession)

  vim.o.sessionoptions = "buffers,tabpages,winsize,winpos,terminal,localoptions"
end

local toggle_session = function()
  local autosession = require("auto-session")
  local autosession_lib = require("auto-session/lib")
  local session_file = ("%s/%s.vim"):format(
    lib.env.dirs.vim.sessions,
    -- https://github.com/rmagatti/auto-session/blob/00334ee24b9a05001ad50221c8daffbeedaa0842/lua/auto-session/lib.lua#L32
    vim.fn.fnamemodify(vim.v.this_session, ":t:r")
    -- autosession_lib.get_session_display_name(vim.fn.getcwd())
  )
  -- log(session_file)
  local has_session = lib.fs.file.is_readable(session_file)
  if has_session then
    autosession.delete_session()
    -- log("Deleted session")
  else
    autosession.save_session()
    -- log("Created session")
  end
end

return lib.module.create({
  name = "workflow/sessions",
  -- enabled = false,
  hosts = "*",
  plugins = {
    {
      "rmagatti/auto-session",
      -- commit = "2102c228854a2d74fbf35374aa86feac3f538da1",
      lazy = false,
      config = setup_auto_session,
    },
  },
  mappings = {
    { "n", "<leader>s", toggle_session, "Toggle session" },
  },
})

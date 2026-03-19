local configured_servers = require("config/lsp-servers")

local state = {
  buf = nil,
  win = nil,
}

local sort_clients = function(clients)
  table.sort(clients, function(left, right)
    if left.name == right.name then return left.id < right.id end
    return left.name < right.name
  end)
end

local format_path = function(path)
  if type(path) ~= "string" or path == "" then return "-" end
  return vim.fn.fnamemodify(path, ":~")
end

local format_cmd = function(cmd)
  if type(cmd) == "string" then return cmd end
  if type(cmd) ~= "table" then return "-" end

  local parts = {}
  for _, value in ipairs(cmd) do
    parts[#parts + 1] = tostring(value)
  end

  if #parts == 0 then return "-" end
  return table.concat(parts, " ")
end

local format_diagnostics = function(bufnr)
  local counts = vim.diagnostic.count(bufnr)
  if type(counts) ~= "table" then return "E0 W0 I0 H0" end

  local severity = vim.diagnostic.severity
  return string.format(
    "E%d W%d I%d H%d",
    counts[severity.ERROR] or 0,
    counts[severity.WARN] or 0,
    counts[severity.INFO] or 0,
    counts[severity.HINT] or 0
  )
end

local format_attached_buffers = function(client)
  local bufnrs = {}
  for bufnr, attached in pairs(client.attached_buffers or {}) do
    if attached then bufnrs[#bufnrs + 1] = bufnr end
  end

  table.sort(bufnrs)
  if #bufnrs == 0 then return "none" end

  return table.concat(vim.tbl_map(tostring, bufnrs), ", ")
end

local format_pending_requests = function(client)
  local methods = {}
  local seen = {}

  for _, request in pairs(client.requests or {}) do
    if request and request.type == "pending" and request.method and not seen[request.method] then
      seen[request.method] = true
      methods[#methods + 1] = request.method
    end
  end

  table.sort(methods)
  if #methods == 0 then return "none" end
  return table.concat(methods, ", ")
end

local format_progress = function(client)
  local titles = {}
  local seen = {}

  local pending = (client.progress or {}).pending or {}
  for _, title in pairs(pending) do
    if type(title) == "string" and title ~= "" and not seen[title] then
      seen[title] = true
      titles[#titles + 1] = title
    end
  end

  table.sort(titles)
  if #titles == 0 then return "idle" end
  return table.concat(titles, ", ")
end

local format_root_markers = function(root_markers)
  if type(root_markers) ~= "table" or vim.tbl_isempty(root_markers) then return "-" end

  local parts = {}
  for _, marker in ipairs(root_markers) do
    if type(marker) == "table" then
      parts[#parts + 1] = "(" .. table.concat(vim.tbl_map(tostring, marker), " | ") .. ")"
    else
      parts[#parts + 1] = tostring(marker)
    end
  end

  return table.concat(parts, ", ")
end

local supports_filetype = function(config, filetype)
  if filetype == nil or filetype == "" then return true end
  if type(config) ~= "table" or config.filetypes == nil then return true end
  return vim.tbl_contains(config.filetypes, filetype)
end

local build_lines = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype
  local buffer_path = vim.api.nvim_buf_get_name(bufnr)

  local attached_clients = vim.lsp.get_clients({ bufnr = bufnr })
  local active_clients = vim.lsp.get_clients()
  sort_clients(attached_clients)
  sort_clients(active_clients)

  local matching_configs = {}
  for _, server in ipairs(configured_servers) do
    local config = vim.lsp.config[server]
    if config and supports_filetype(config, filetype) then
      matching_configs[#matching_configs + 1] = {
        name = server,
        enabled = vim.lsp.is_enabled(server),
        root_markers = config.root_markers,
      }
    end
  end

  table.sort(matching_configs, function(left, right)
    return left.name < right.name
  end)

  local ft_label = filetype ~= "" and filetype or "*"
  local lines = {
    "LSP Status",
    "",
    "Buffer",
    string.format("- path: %s", format_path(buffer_path)),
    string.format("- filetype: %s", ft_label),
    string.format("- diagnostics: %s", format_diagnostics(bufnr)),
    "",
    string.format("Attached clients (%d)", #attached_clients),
  }

  if #attached_clients == 0 then
    lines[#lines + 1] = "- none"
  else
    for _, client in ipairs(attached_clients) do
      lines[#lines + 1] = string.format("- %s (id %d)", client.name, client.id)
      lines[#lines + 1] = string.format("  root: %s", format_path(client.root_dir))
      lines[#lines + 1] = string.format("  cmd: %s", format_cmd((client.config or {}).cmd))
      lines[#lines + 1] = string.format("  attached buffers: %s", format_attached_buffers(client))
      lines[#lines + 1] = string.format("  pending requests: %s", format_pending_requests(client))
      lines[#lines + 1] = string.format("  work done: %s", format_progress(client))
      lines[#lines + 1] = string.format(
        "  formatting: %s",
        client:supports_method(vim.lsp.protocol.Methods.textDocument_formatting) and "yes" or "no"
      )
    end
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = string.format("Configured servers for `%s` (%d)", ft_label, #matching_configs)
  if #matching_configs == 0 then
    lines[#lines + 1] = "- none"
  else
    for _, item in ipairs(matching_configs) do
      lines[#lines + 1] = string.format("- %s [%s]", item.name, item.enabled and "enabled" or "disabled")
      lines[#lines + 1] = string.format("  root markers: %s", format_root_markers(item.root_markers))
    end
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = string.format("Active clients (%d)", #active_clients)
  if #active_clients == 0 then
    lines[#lines + 1] = "- none"
  else
    for _, client in ipairs(active_clients) do
      lines[#lines + 1] = string.format("- %s (id %d, root %s)", client.name, client.id, format_path(client.root_dir))
    end
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "Hints"
  lines[#lines + 1] = "- :checkhealth vim.lsp shows the builtin health report."
  lines[#lines + 1] = "- :lsp restart restarts active clients for the current buffer."

  return lines
end

local update_buffer = function(lines)
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_set_option_value("buftype", "nofile", { buf = state.buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.buf })
    vim.api.nvim_set_option_value("buflisted", false, { buf = state.buf })
    vim.api.nvim_set_option_value("swapfile", false, { buf = state.buf })
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = state.buf })

    vim.keymap.set("n", "q", function()
      if state.win and vim.api.nvim_win_is_valid(state.win) then vim.api.nvim_win_close(state.win, true) end
    end, { buffer = state.buf, nowait = true, silent = true })

    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = state.buf,
      callback = function()
        state.buf = nil
        state.win = nil
      end,
    })
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf })
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })
end

local open_window = function(lines)
  local max_width = math.max(vim.o.columns - 4, 40)
  local max_height = math.max(vim.o.lines - 4, 12)

  local longest_line = 0
  for _, line in ipairs(lines) do
    longest_line = math.max(longest_line, vim.fn.strdisplaywidth(line))
  end

  local width = math.min(math.max(longest_line + 4, 72), max_width)
  local height = math.min(#lines + 2, max_height)
  local config = {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    title = " LspInfo ",
    title_pos = "center",
    width = width,
    height = height,
    row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 0),
    col = math.max(math.floor((vim.o.columns - width) / 2), 0),
    zindex = 60,
  }

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_config(state.win, config)
    vim.api.nvim_set_current_win(state.win)
  else
    state.win = vim.api.nvim_open_win(state.buf, true, config)
  end

  vim.api.nvim_set_option_value("wrap", false, { win = state.win })
  vim.api.nvim_set_option_value("number", false, { win = state.win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = state.win })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = state.win })
  vim.api.nvim_set_option_value("foldcolumn", "0", { win = state.win })
  vim.api.nvim_set_option_value("cursorline", false, { win = state.win })
  vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
end

local show = function()
  local lines = build_lines()
  update_buffer(lines)
  open_window(lines)
end

local register_user_command = function()
  pcall(vim.api.nvim_del_user_command, "LspInfo")
  vim.api.nvim_create_user_command("LspInfo", show, {
    desc = "Show current LSP status",
    force = true,
  })
end

return {
  register_user_command = register_user_command,
  show = show,
}

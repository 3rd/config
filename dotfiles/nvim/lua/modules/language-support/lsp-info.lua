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
  local severity = vim.diagnostic.severity
  if type(counts) ~= "table" then counts = {} end

  return string.format(
    "E%d W%d I%d H%d",
    counts[severity.ERROR] or 0,
    counts[severity.WARN] or 0,
    counts[severity.INFO] or 0,
    counts[severity.HINT] or 0
  )
end

local format_diagnostic_counts = function(counts)
  local severity = vim.diagnostic.severity
  if type(counts) ~= "table" then counts = {} end

  return string.format(
    "E%d W%d I%d H%d",
    counts[severity.ERROR] or 0,
    counts[severity.WARN] or 0,
    counts[severity.INFO] or 0,
    counts[severity.HINT] or 0
  )
end

local count_namespace_diagnostics = function(bufnr, namespace)
  local counts = {}
  local severity = vim.diagnostic.severity

  for _, diagnostic in ipairs(vim.diagnostic.get(bufnr, { namespace = namespace })) do
    counts[diagnostic.severity] = (counts[diagnostic.severity] or 0) + 1
  end

  counts.total = (counts[severity.ERROR] or 0)
    + (counts[severity.WARN] or 0)
    + (counts[severity.INFO] or 0)
    + (counts[severity.HINT] or 0)

  return counts
end

local format_namespace_name = function(namespace)
  if type(namespace) ~= "number" then return "-" end

  local namespace_config = vim.diagnostic.get_namespaces()[namespace]
  local name = type(namespace_config) == "table" and namespace_config.name or nil
  if type(name) ~= "string" or name == "" then return tostring(namespace) end

  local client_name = name:match("^nvim%.lsp%.([^.]+)%.%d+$")
  if client_name then return client_name end

  return name
end

local format_namespace_diagnostics = function(bufnr)
  local parts = {}

  for namespace in pairs(vim.diagnostic.get_namespaces()) do
    local counts = count_namespace_diagnostics(bufnr, namespace)
    if counts.total and counts.total > 0 then
      parts[#parts + 1] = string.format("%s %s", format_namespace_name(namespace), format_diagnostic_counts(counts))
    end
  end

  table.sort(parts)
  if #parts == 0 then return "none" end
  return table.concat(parts, "; ")
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

local format_workspace_folders = function(client)
  local workspace_folders = client and client.workspace_folders or nil
  if type(workspace_folders) ~= "table" or vim.tbl_isempty(workspace_folders) then return "-" end

  local folders = {}
  for _, folder in ipairs(workspace_folders) do
    local uri = type(folder) == "table" and folder.uri or nil
    if type(uri) == "string" and uri ~= "" then
      local ok, path = pcall(vim.uri_to_fname, uri)
      folders[#folders + 1] = ok and format_path(path) or uri
    end
  end

  if #folders == 0 then return "-" end
  return table.concat(folders, ", ")
end

local format_client_namespace = function(client)
  if not client or type(client.namespace) ~= "number" then return "-" end
  return string.format("%s (%d)", format_namespace_name(client.namespace), client.namespace)
end

local format_client_diagnostics = function(bufnr, client)
  if not client or type(client.namespace) ~= "number" then return "-" end
  return format_diagnostic_counts(count_namespace_diagnostics(bufnr, client.namespace))
end

local format_filetypes = function(filetypes)
  if type(filetypes) ~= "table" or vim.tbl_isempty(filetypes) then return "-" end

  local limit = 4
  local items = {}
  for index, filetype in ipairs(filetypes) do
    if index > limit then break end
    items[#items + 1] = tostring(filetype)
  end

  if #filetypes <= limit then return table.concat(items, ", ") end
  return string.format("%s (+%d more)", table.concat(items, ", "), #filetypes - limit)
end

local format_workspace_required = function(value)
  if value == nil then return "-" end
  return value and "yes" or "no"
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
        filetypes = config.filetypes,
        workspace_required = config.workspace_required,
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
    string.format("- diagnostic sources: %s", format_namespace_diagnostics(bufnr)),
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
      lines[#lines + 1] = string.format("  namespace: %s", format_client_namespace(client))
      lines[#lines + 1] = string.format("  diagnostics: %s", format_client_diagnostics(bufnr, client))
      lines[#lines + 1] = string.format("  attached buffers: %s", format_attached_buffers(client))
      lines[#lines + 1] = string.format("  workspace folders: %s", format_workspace_folders(client))
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
      lines[#lines + 1] = string.format("  filetypes: %s", format_filetypes(item.filetypes))
      lines[#lines + 1] = string.format("  workspace required: %s", format_workspace_required(item.workspace_required))
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

local M = {}

local get_line_diagnostics = function(bufnr)
  local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1

  if vim.fn.has("nvim-0.11") == 1 then
    local diagnostics = vim.diagnostic.get(bufnr, { lnum = current_line })
    local for_lsp_diagnostics = {}

    table.sort(diagnostics, function(a, b)
      return math.abs(a.lnum - current_line) < math.abs(b.lnum - current_line)
    end)

    for _, diagnostic in ipairs(diagnostics) do
      if diagnostic.user_data and diagnostic.user_data.lsp then
        table.insert(for_lsp_diagnostics, diagnostic.user_data.lsp)
      end
    end

    return for_lsp_diagnostics
  end

  return vim.lsp.diagnostic.get_line_diagnostics(bufnr)[current_line] or {}
end

local build_code_action_params = function(request_opts)
  local position_encoding = vim.api.nvim_get_option_value("encoding", { scope = "local" })
  local params

  if request_opts.range then
    params = {
      textDocument = { uri = vim.uri_from_bufnr(request_opts.bufnr) },
      range = {
        start = { line = request_opts.range.start[1] - 1, character = request_opts.range.start[2] },
        ["end"] = { line = request_opts.range["end"][1] - 1, character = request_opts.range["end"][2] },
      },
    }
  elseif vim.fn.mode() == "n" then
    params = {
      textDocument = { uri = vim.uri_from_bufnr(request_opts.bufnr) },
      range = vim.lsp.util.make_range_params(0, position_encoding).range,
    }
  else
    params = {
      textDocument = { uri = vim.uri_from_bufnr(request_opts.bufnr) },
      range = vim.lsp.util.make_given_range_params(
        { vim.fn.getpos("'<")[2], vim.fn.getpos("'<")[3] },
        { vim.fn.getpos("'>")[2], vim.fn.getpos("'>")[3] },
        0,
        position_encoding
      ).range,
    }
  end

  local context = {}
  if request_opts.context and request_opts.context.triggerKind then
    context.triggerKind = request_opts.context.triggerKind
  else
    context.triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked
  end

  if request_opts.context and request_opts.context.diagnostics then
    context.diagnostics = request_opts.context.diagnostics
  else
    context.diagnostics = get_line_diagnostics(request_opts.bufnr)
  end

  if request_opts.context and request_opts.context.only then context.only = request_opts.context.only end

  params.context = context

  return params, context
end

local configure_code_action_finder = function(config)
  local finder = require("tiny-code-action.finder")

  if finder._original_code_action_finder == nil then
    finder._original_code_action_finder = finder.code_action_finder
  end

  if config.async ~= false then
    finder.code_action_finder = finder._original_code_action_finder
    return
  end

  finder.code_action_finder = function(request_opts, callback)
    local clients = vim.lsp.get_clients({ bufnr = request_opts.bufnr, method = "textDocument/codeAction" })
    if not clients or #clients == 0 then return nil end

    local params, context = build_code_action_params(request_opts)
    local ok, responses, err = pcall(
      vim.lsp.buf_request_sync,
      request_opts.bufnr,
      "textDocument/codeAction",
      params,
      config.code_action_request_timeout_ms
    )

    if not ok then
      vim.notify("Failed to fetch code actions: " .. tostring(responses), vim.log.levels.ERROR)
      return nil
    end

    if err then vim.notify("Code action request timed out: " .. tostring(err), vim.log.levels.WARN) end

    local results = {}

    for client_id, response in pairs(responses or {}) do
      if response and response.result then
        local client = vim.lsp.get_client_by_id(client_id)
        if client then
          for _, action in ipairs(response.result) do
            table.insert(results, {
              client = client,
              action = action,
              context = context,
            })
          end
        end
      end
    end

    if vim.tbl_isempty(results) then
      vim.notify("No code actions found.", vim.log.levels.INFO)
      return nil
    end

    callback(results)
  end
end

M.setup = function(opts, config)
  local plugin = require("tiny-code-action")
  plugin.setup(opts)
  configure_code_action_finder(config)
  return plugin
end

return M

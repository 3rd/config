-- custom @/project-root/.. source

local M = {}

local find_file_reference = function(context)
  if not context.line or not context.pos then return end
  local prefix = context.line:sub(1, context.pos.col)
  local start_col, query = prefix:match("()@([^%s]*)$")
  if not start_col then return end
  if start_col > 1 and not prefix:sub(start_col - 1, start_col - 1):match("%s") then return end
  return start_col, query
end

local empty_response = function()
  return {
    is_incomplete_forward = false,
    is_incomplete_backward = false,
    items = {},
  }
end

M.new = function()
  local self = setmetatable({}, { __index = M })
  return self
end

function M:get_trigger_characters()
  return { "@" }
end

function M:should_show_items(context)
  if
    context
    and context.trigger
    and context.trigger.initial_kind == "manual"
    and context.providers
    and #context.providers == 1
    and context.providers[1] == "files"
  then
    return true
  end

  return find_file_reference(context) ~= nil
end

function M:get_completions(context, callback)
  if not self:should_show_items(context) then
    callback(empty_response())
    return
  end

  local cwd = vim.fn.getcwd()

  local start_col, query = find_file_reference(context)
  local text_range
  if start_col then
    local suffix = context.line:sub(context.pos.col + 1):match("^%S*")
    text_range = {
      start = { line = context.pos.row, character = start_col },
      ["end"] = { line = context.pos.row, character = context.pos.col + #suffix },
    }
  end

  local cmd = "fd --type f --hidden --exclude .git 2>/dev/null || find "
    .. vim.fn.shellescape(cwd)
    .. " -type f -not -path '*/\\.git/*' 2>/dev/null"

  local canceled = false
  local completed = false
  local complete = function(response)
    if canceled or completed then return end

    completed = true
    callback(response)
  end

  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if canceled or not data then return end

      local items = {}
      for _, line in ipairs(data) do
        if line ~= "" then
          local relative_path = line
          if vim.startswith(line, cwd) then relative_path = line:sub(#cwd + 2) end

          local sort_priority = 90
          local basename = vim.fn.fnamemodify(relative_path, ":t")

          if query and query ~= "" then
            local lower_path = relative_path:lower()
            local lower_basename = basename:lower()
            local lower_query = query:lower()

            -- exact filename match
            if lower_basename == lower_query then
              sort_priority = 10
            -- exact path match
            elseif lower_path == lower_query then
              sort_priority = 20
            -- filename starts with query
            elseif vim.startswith(lower_basename, lower_query) then
              sort_priority = 30
            -- path starts with query
            elseif vim.startswith(lower_path, lower_query) then
              sort_priority = 40
            -- filename contains query
            elseif lower_basename:find(lower_query, 1, true) then
              sort_priority = 50
            -- path contains query
            elseif lower_path:find(lower_query, 1, true) then
              sort_priority = 60
            end
          end

          local sort_text = string.format("%02d_%s", sort_priority, relative_path)

          table.insert(items, {
            label = relative_path,
            kind = require("blink.cmp.types").CompletionItemKind.File,
            insertText = relative_path,
            textEdit = text_range and { newText = relative_path, range = text_range } or nil,
            filterText = relative_path,
            sortText = sort_text,
            documentation = {
              kind = "plaintext",
              value = "File: " .. relative_path,
            },
          })
        end
      end

      complete({
        is_incomplete_forward = false,
        is_incomplete_backward = false,
        items = items,
      })
    end,
    on_stderr = function(_, data) end,
    on_exit = function(_, code)
      if code ~= 0 then complete(empty_response()) end
    end,
  })

  if job_id <= 0 then
    complete(empty_response())
    return
  end

  return function()
    if canceled or completed then return end

    canceled = true
    vim.fn.jobstop(job_id)
  end
end

return M

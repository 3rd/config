-- custom @/project-root/.. source

local M = {}

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

  local line = context.line
  local cursor = context.cursor

  if not line or not cursor then return false end

  local starts_with_at = line:match("^@")
  local has_space_at = line:match("%s@")

  return starts_with_at ~= nil or has_space_at ~= nil
end

function M:get_completions(context, callback)
  local cwd = vim.fn.getcwd()

  local context_line = context.line
  local cursor = context.cursor
  local query = ""

  if context_line and cursor then
    local at_start_match = context_line:match("^@([^%s]*)")
    local at_space_match = context_line:match("%s@([^%s]*)")

    if at_start_match then
      query = at_start_match
    elseif at_space_match then
      query = at_space_match
    end
  end

  local cmd = "fd --type f --hidden --exclude .git 2>/dev/null || find "
    .. vim.fn.shellescape(cwd)
    .. " -type f -not -path '*/\\.git/*' 2>/dev/null"

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data then return end

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
            filterText = relative_path,
            sortText = sort_text,
            documentation = {
              kind = "plaintext",
              value = "File: " .. relative_path,
            },
          })
        end
      end

      callback({
        is_incomplete_forward = false,
        is_incomplete_backward = false,
        items = items,
      })
    end,
    on_stderr = function(_, data) end,
    on_exit = function(_, code)
      if code ~= 0 then
        callback({
          is_incomplete_forward = false,
          is_incomplete_backward = false,
          items = {},
        })
      end
    end,
  })
end

return M

local list_nodes = function()
  local command = "WIKI_ROOT=$HOME/brain/wiki TASK_ROOT=$HOME/brain/wiki core wiki ls | sort"
  return string.split(vim.fn.trim(lib.shell.exec(command)), "\n")
end

local source = {}

source.new = function()
  local self = setmetatable({}, { __index = source })
  return self
end

function source.is_available()
  return vim.bo.filetype == "syslang"
end

function source.get_debug_name()
  return "syslang"
end

function source.get_trigger_characters()
  return { "[" }
end

function source.complete(_, request, callback)
  local text_before = request.context.cursor_before_line
  local text_after = request.context.cursor_after_line

  local insert_start = nil
  -- local insert_end = nil
  -- local query = ""
  for i = #text_before, 1, -1 do
    local sub = text_before:sub(i, i + 1)
    if sub == "]]" then return callback({ isIncomplete = true }) end
    if sub == "[[" then
      insert_start = i - 1
      -- insert_end = #text_before
      -- query = text_before:sub(i + 2, insert_end)
      break
    end
  end
  if insert_start == nil then return callback({ isIncomplete = true }) end

  local nodes = list_nodes()
  local items = {}
  local needs_trailing_bracket = not vim.startswith(text_after, "]")

  for _, node in ipairs(nodes) do
    table.insert(items, {
      label = node,
      kind = 20,
      additionalTextEdits = {
        needs_trailing_bracket and {
          newText = "]]",
          range = {
            start = {
              line = request.context.cursor.row - 1,
              character = request.context.cursor.col + #node,
            },
            ["end"] = {
              line = request.context.cursor.row - 1,
              character = request.context.cursor.col + #node,
            },
          },
        } or nil,
      },
    })
  end

  callback({ items = items or {}, isIncomplete = false })
end

function source.resolve(_, completion_item, callback)
  callback(completion_item)
end

function source.execute(_, completion_item, callback)
  callback(completion_item)
end

return source

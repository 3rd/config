local wiki = require("modules.wiki.api")

local M = {}

local empty_response = function()
  return {
    is_incomplete_forward = false,
    is_incomplete_backward = false,
    items = {},
  }
end

local find_link_start = function(line, cursor_col)
  local text_before_cursor = line:sub(1, cursor_col)
  local link_start
  local index = 1

  while index < #text_before_cursor do
    local pair = text_before_cursor:sub(index, index + 1)
    if pair == "[[" then
      link_start = index
      index = index + 2
    elseif pair == "]]" then
      link_start = nil
      index = index + 2
    else
      index = index + 1
    end
  end

  return link_start
end

M.new = function()
  return setmetatable({}, { __index = M })
end

function M:get_trigger_characters()
  return { "[" }
end

function M:should_show_items(context)
  return context.line and context.pos and find_link_start(context.line, context.pos.col) ~= nil
end

function M:get_completions(context, callback)
  local line = context.line
  local position = context.pos
  if not line or not position then
    callback(empty_response())
    return
  end

  local link_start = find_link_start(line, position.col)
  if not link_start then
    callback(empty_response())
    return
  end

  local suffix = line:sub(position.col + 1)
  local closing_text = "]]"
  if vim.startswith(suffix, "]]") then
    closing_text = ""
  elseif vim.startswith(suffix, "]") then
    closing_text = "]"
  end

  return wiki.list_nodes_async(function(nodes, list_error)
    if not nodes then
      vim.notify_once("Could not complete wiki links: " .. list_error, vim.log.levels.WARN)
      callback(empty_response())
      return
    end

    local items = {}
    for _, node in ipairs(nodes) do
      items[#items + 1] = {
        label = node,
        kind = require("blink.cmp.types").CompletionItemKind.Reference,
        filterText = node,
        textEdit = {
          newText = node .. closing_text,
          range = {
            start = { line = position.row, character = link_start + 1 },
            ["end"] = { line = position.row, character = position.col },
          },
        },
      }
    end

    callback({
      is_incomplete_forward = false,
      is_incomplete_backward = false,
      items = items,
    })
  end)
end

return M

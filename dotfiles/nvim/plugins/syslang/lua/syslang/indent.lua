local outline_node_types = { "outline_1", "outline_2", "outline_3", "outline_4", "outline_5", "outline_6" }

-- TODO: indent suboutlines, dedent
local handle_indent = function()
  -- local ts_utils = require("nvim-treesitter.ts_utils")
  local outline_node = lib.ts.find_parent_at_line(outline_node_types)
  if outline_node ~= nil then
    local outline_level = outline_node:type():match("%d")
    local outline_node_range = vim.treesitter.node_to_lsp_range(outline_node)

    local outline_text_node = lib.ts.find_child(outline_node, "text_to_eol")
    if outline_text_node == nil then throw("no text node found") end
    local outline_text = vim.treesitter.get_node_text(outline_text_node, 0)
    local outline_text_range = vim.treesitter.node_to_lsp_range(outline_text_node)

    local newIndent = string.rep("  ", outline_level)
    local newMarker = string.rep("*", outline_level + 1)
    local newText = newIndent .. newMarker .. " " .. outline_text
    local row = vim.fn.line(".") - 1

    -- adjust indent for all child lines
    local children_lines = string.split(vim.treesitter.get_node_text(outline_node, 0), "\n")
    if #children_lines > 1 then
      -- log("children_lines", children_lines)
      local newLines = {}
      -- skip first and regulate indent for all other lines
      -- local previousChildIndent = string.rep("  ", outline_level)
      -- local newChildIndent = string.rep("  ", outline_level + 1)
      for i = 2, #children_lines do
        local childLine = children_lines[i]
        -- if childLine:match("^" .. previousChildIndent) then
        --   childLine = childLine:gsub("^" .. previousChildIndent, "")
        -- end
        -- childLine = newChildIndent .. childLine
        childLine = "  " .. childLine
        table.insert(newLines, childLine)
      end
      local newChildrenText = table.concat(newLines, "\n")
      -- log("children", {
      --   previousIndent = previousChildIndent,
      --   newIndent = newChildIndent,
      --   lines = newLines,
      -- })

      local edit = {
        range = {
          start = { line = row + 1, character = 0 },
          ["end"] = { line = outline_node_range["end"].line, character = outline_node_range["end"].character },
        },
        newText = newChildrenText,
      }

      local buf = vim.api.nvim_get_current_buf()
      vim.lsp.util.apply_text_edits({ edit }, buf, "utf-8")
    end

    -- replace outline text
    -- log("replace outline text", newText)
    local edit = {
      range = {
        start = { line = row, character = 0 },
        ["end"] = { line = outline_node_range.start.line, character = outline_text_range["end"].character },
      },
      newText = newText,
    }
    local buf = vim.api.nvim_get_current_buf()
    vim.lsp.util.apply_text_edits({ edit }, buf, "utf-8")

    return
  end

  -- fallback to default indent
  vim.cmd("normal! >>")
end

local handle_dedent = function()
  log("dedent")
  vim.cmd("normal! <<")
end

return {
  handle_indent = handle_indent,
  handle_dedent = handle_dedent,
}

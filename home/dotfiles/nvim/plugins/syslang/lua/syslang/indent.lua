-- TODO: indent subheadings, dedent
local heading_node_types = { "heading_1", "heading_2", "heading_3", "heading_4", "heading_5", "heading_6" }
local handle_indent = function()
  local ts_utils = require("nvim-treesitter.ts_utils")
  local heading_node = lib.ts.find_parent_at_line(heading_node_types)
  if heading_node ~= nil then
    local heading_level = heading_node:type():match("%d")
    local heading_node_range = ts_utils.node_to_lsp_range(heading_node)

    local heading_text_node = lib.ts.find_child(heading_node, "text_to_eol")
    if heading_text_node == nil then throw("no text node found") end
    local heading_text = vim.treesitter.get_node_text(heading_text_node, 0)
    local heading_text_range = ts_utils.node_to_lsp_range(heading_text_node)

    local newIndent = string.rep("  ", heading_level)
    local newMarker = string.rep("*", heading_level + 1)
    local newText = newIndent .. newMarker .. " " .. heading_text
    local row = vim.fn.line(".") - 1

    -- adjust indent for all child lines
    local children_lines = string.split(vim.treesitter.get_node_text(heading_node, 0), "\n")
    if #children_lines > 1 then
      -- log("children_lines", children_lines)
      local newLines = {}
      -- skip first and regulate indent for all other lines
      -- local previousChildIndent = string.rep("  ", heading_level)
      -- local newChildIndent = string.rep("  ", heading_level + 1)
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
          ["end"] = { line = heading_node_range["end"].line, character = heading_node_range["end"].character },
        },
        newText = newChildrenText,
      }
      vim.lsp.util.apply_text_edits({ edit }, 0, "utf-8")
    end

    -- replace heading text
    -- log("replace heading text", newText)
    local edit = {
      range = {
        start = { line = row, character = 0 },
        ["end"] = { line = heading_node_range.start.line, character = heading_text_range["end"].character },
      },
      newText = newText,
    }
    vim.lsp.util.apply_text_edits({ edit }, 0, "utf-8")

    return
  end

  -- fallback to default indent
  vim.cmd("normal! >>")
end
local handle_dedent = function()
  log("dedent")
  vim.cmd("normal! <<")
end

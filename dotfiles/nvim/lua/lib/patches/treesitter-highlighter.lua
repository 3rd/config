local M = {}
local treesitter = require("lib/treesitter")

M.setup = function()
  local highlighter = vim.treesitter.highlighter
  if highlighter.has_region_filter then return end

  highlighter.prepare_highlight_states = function(self, start_row, end_row)
    self._highlight_states = {}
    treesitter.for_each_tree_in_range(self.tree, start_row, end_row, function(tree, language_tree)
      local query = self:get_query(language_tree:lang())
      if not query:query() then return end

      table.insert(self._highlight_states, {
        tstree = tree,
        next_row = 0,
        next_col = 0,
        highlighter_query = query,
      })
    end)
  end
  highlighter.has_region_filter = true
end

return M

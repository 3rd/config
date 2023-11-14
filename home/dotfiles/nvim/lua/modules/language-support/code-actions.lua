local filtered_code_actions = { "Move to a new file" }

local handle_code_action = function()
  vim.lsp.buf.code_action({
    filter = function(action)
      return not vim.tbl_contains(filtered_code_actions, action.title)
    end,
  })
end

return {
  code_action = handle_code_action,
}

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
require("lib.string")

local finder = { code_action_finder = function() end }
local original_finder = finder.code_action_finder
local configured_options
local action_options
local mappings = {}
package.loaded["tiny-code-action.finder"] = finder
package.loaded["tiny-code-action"] = {
  setup = function(options)
    configured_options = options
    assert(finder.code_action_finder == original_finder)
  end,
  code_action = function(options)
    action_options = options
  end,
}
_G.lib = {
  module = {
    create = function(module)
      return module
    end,
  },
  map = {
    map = function(_, lhs, callback)
      mappings[lhs] = callback
    end,
  },
}
require("modules.language-support.code-actions").plugins[1].config()
assert(configured_options.picker.opts.auto_accept)
assert(finder._original_code_action_finder == original_finder)
mappings["<leader>ac"]()
assert(action_options.filter({ title = "Fix assignment", kind = "quickfix" }))
assert(not action_options.filter({ title = "Extract function", kind = "refactor.extract" }))

local bufnr = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "alpha", "beta", "gamma" })
vim.api.nvim_win_set_cursor(0, { 2, 1 })
local client = { id = 7 }
local clients = { client }
local action = { title = "Use const", kind = "refactor.rewrite" }
local next_action = { title = "Add import", kind = "quickfix" }
local responses = { [7] = { result = { action, next_action } }, [8] = { result = { { title = "Stale" } } } }
local request_error
local should_throw = false
local sent_request
local notifications = {}
local get_clients = vim.lsp.get_clients
vim.notify = function(message, level)
  table.insert(notifications, { message, level })
end
vim.lsp.get_clients = function(options)
  assert(options.bufnr == bufnr and options.method == "textDocument/codeAction")
  return clients
end
vim.lsp.get_client_by_id = function(id)
  return id == 7 and client or nil
end
vim.lsp.buf_request_sync = function(buffer, method, params, timeout)
  sent_request = { buffer = buffer, method = method, params = params, timeout = timeout }
  if should_throw then error("request failed", 0) end
  return responses, request_error
end

local returned_actions
local request_actions = function(options)
  returned_actions = nil
  sent_request = nil
  finder.code_action_finder(options, function(actions)
    returned_actions = actions
  end)
end

local context = { triggerKind = 2, diagnostics = { { message = "explicit" } }, only = { "refactor" } }
request_actions({ bufnr = bufnr, range = { start = { 1, 2 }, ["end"] = { 3, 4 } }, context = context })
assert(sent_request.buffer == bufnr and sent_request.method == "textDocument/codeAction")
assert(sent_request.timeout == 2000)
assert(sent_request.params.textDocument.uri == vim.uri_from_bufnr(bufnr))
assert(
  vim.deep_equal(
    sent_request.params.range,
    { start = { line = 0, character = 2 }, ["end"] = { line = 2, character = 4 } }
  )
)
assert(vim.deep_equal(sent_request.params.context, context))
assert(#returned_actions == 2 and returned_actions[1].client == client and returned_actions[1].action == action)
assert(returned_actions[2].action == next_action)
assert(returned_actions[1].context == sent_request.params.context)

local lsp_diagnostic = { message = "line diagnostic", range = sent_request.params.range }
vim.diagnostic.set(vim.api.nvim_create_namespace("code-action-spec"), bufnr, {
  { lnum = 1, col = 0, message = "line diagnostic", user_data = { lsp = lsp_diagnostic } },
  { lnum = 1, col = 1, message = "non-LSP diagnostic" },
  { lnum = 0, col = 0, message = "other line", user_data = { lsp = { message = "other line" } } },
})
local cursor_range = vim.lsp.util.make_range_params(0, "utf-8").range
request_actions({ bufnr = bufnr })
assert(vim.deep_equal(sent_request.params.range, cursor_range))
assert(sent_request.params.context.triggerKind == vim.lsp.protocol.CodeActionTriggerKind.Invoked)
assert(vim.deep_equal(sent_request.params.context.diagnostics, { lsp_diagnostic }))

vim.fn.mode = function()
  return "v"
end
vim.fn.setpos("'<", { bufnr, 1, 1, 0 })
vim.fn.setpos("'>", { bufnr, 2, 2, 0 })
local visual_range = vim.lsp.util.make_given_range_params({ 1, 1 }, { 2, 2 }, 0, "utf-8").range
request_actions({ bufnr = bufnr })
assert(vim.deep_equal(sent_request.params.range, visual_range))

clients = {}
request_actions({ bufnr = bufnr })
assert(sent_request == nil and returned_actions == nil and #notifications == 0)

clients = { client }
should_throw = true
request_actions({ bufnr = bufnr })
assert(returned_actions == nil)
assert(
  vim.deep_equal(
    notifications[#notifications],
    { "Failed to fetch code actions: request failed", vim.log.levels.ERROR }
  )
)

should_throw = false
request_error = "timeout"
request_actions({ bufnr = bufnr })
assert(#returned_actions == 2)
assert(
  vim.deep_equal(notifications[#notifications], { "Code action request timed out: timeout", vim.log.levels.WARN })
)

request_error = nil
responses = { [8] = { result = { { title = "Stale" } } }, [7] = { error = { message = "unavailable" } } }
request_actions({ bufnr = bufnr })
assert(returned_actions == nil)
assert(vim.deep_equal(notifications[#notifications], { "No code actions found.", vim.log.levels.INFO }))
vim.lsp.get_clients = get_clients

package.loaded["tiny-code-action"].setup = function() end
require("lib.patches.tiny-code-action").setup(configured_options, { async = true })
assert(finder.code_action_finder == original_finder and finder._original_code_action_finder == original_finder)
print("code-actions_spec: ok")

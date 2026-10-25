require("lib")
for _, plugin in ipairs({ "nvim-treesitter", "nvim-treesitter-textobjects" }) do
  vim.opt.runtimepath:prepend(lib.env.dirs.vim.lazy.root .. "/" .. plugin)
end

require("modules.language-support.tree-sitter").plugins[1].config()
local source = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(source, 0, -1, false, { "é😀x" })
vim.api.nvim_win_set_cursor(0, { 1, 6 })
local target = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(target, vim.fn.tempname() .. ".js")
vim.bo[target].filetype = "javascript"

local clients = {}
local requests = {}
for id, encoding in ipairs({ "utf-8", "utf-16" }) do
  table.insert(clients, {
    id = id,
    offset_encoding = encoding,
    supports_method = function()
      return true
    end,
    request = function(_, method, params, handler, bufnr)
      requests[id] = { params = params, handler = handler, context = { client_id = id, bufnr = bufnr } }
      assert(method == "textDocument/definition")
      return true, 1
    end,
  })
end

local get_clients = vim.lsp.get_clients
vim.lsp.get_clients = function()
  return clients
end
vim.lsp.get_client_by_id = function(id)
  return clients[id]
end

local cases = {
  {
    key = "<leader>k",
    lines = { "/* é😀 */ function target() {", "  return 1;", "}" },
    client_id = 2,
    column = 10,
  },
  {
    key = "<leader>K",
    lines = { "/* é😀 */ class Box {", "  value() { return 1; }", "}" },
    client_id = 1,
    column = 13,
  },
}
for _, case in ipairs(cases) do
  vim.api.nvim_buf_set_lines(target, 0, -1, false, case.lines)
  vim.fn.maparg(case.key, "n", false, true).callback()
  assert(requests[1].params.position.character == 6 and requests[2].params.position.character == 3)
  assert(requests[1].params.textDocument.uri == vim.uri_from_bufnr(source))

  local request = requests[case.client_id]
  request.handler(nil, {
    uri = vim.uri_from_bufnr(target),
    range = { start = { line = 0, character = case.column }, ["end"] = { line = 0, character = case.column + 8 } },
  }, request.context)
  assert(vim.wait(1000, function()
    return #vim.api.nvim_list_wins() == 2
  end))

  local preview = vim.api.nvim_list_wins()[2]
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(preview), 0, -1, false), case.lines))
  vim.api.nvim_win_close(preview, true)
end

vim.lsp.get_clients = get_clients
print("ok: definition previews and per-client Unicode positions")

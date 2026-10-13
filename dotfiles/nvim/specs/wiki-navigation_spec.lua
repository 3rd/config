require("lib")

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local target_path = root .. "/wiki node"
vim.fn.writefile({ "# Synthetic wiki node" }, target_path)
local selected
local resolved_ids = {}
local list_error
local resolve_error
local notification
local expected_entries
package.loaded["modules.wiki.api"] = {
  list_nodes = function()
    if list_error then return nil, list_error end
    return { "node-one" }
  end,
  list_projects = function()
    return { "project-one" }
  end,
  resolve_node = function(id)
    table.insert(resolved_ids, id)
    if resolve_error then return nil, resolve_error end
    return target_path
  end,
}
package.loaded.fzf = {
  provided_win_fzf = function(entries, options)
    assert(vim.deep_equal(entries, expected_entries))
    assert(options == "--print-query --nth 1 --print-query --expect=ctrl-s,ctrl-v,ctrl-x")
    vim.cmd.close()
    return selected
  end,
}
vim.notify = function(message, level)
  notification = { message, level }
end

local wiki = require("modules/wiki")
for _, case in ipairs({
  { mapping = 1, key = "", entries = { "node-one" }, expected_id = "node-one", windows = 1 },
  { mapping = 3, key = "ctrl-s", entries = { "project-one" }, expected_id = "project-one", windows = 2 },
  { mapping = 1, key = "ctrl-v", entries = { "node-one" }, expected_id = "node-one", windows = 2 },
  { mapping = 3, key = "ctrl-x", entries = { "project-one" }, expected_id = "typed query", windows = 1 },
}) do
  vim.cmd("only!")
  expected_entries = case.entries
  selected = { "typed query", case.key, case.entries[1] }
  wiki.mappings[case.mapping][3]()
  assert(resolved_ids[#resolved_ids] == case.expected_id)
  assert(vim.api.nvim_buf_get_name(0) == target_path, "picker must open the resolved path with spaces intact")
  assert(vim.fn.winnr("$") == case.windows)
  if case.key == "ctrl-s" then assert(vim.fn.winlayout()[1] == "col") end
  if case.key == "ctrl-v" then assert(vim.fn.winlayout()[1] == "row") end
end

vim.cmd("only!")
selected = nil
expected_entries = { "node-one" }
local previous_resolutions = #resolved_ids
wiki.mappings[1][3]()
assert(#resolved_ids == previous_resolutions and vim.api.nvim_buf_get_name(0) == target_path)

selected = { "", "", "node-one" }
resolve_error = "missing node"
wiki.mappings[1][3]()
assert(vim.deep_equal(notification, { "Could not resolve wiki node: missing node", vim.log.levels.ERROR }))
assert(vim.api.nvim_buf_get_name(0) == target_path)

list_error = "unavailable"
wiki.mappings[1][3]()
assert(vim.deep_equal(notification, { "Could not list wiki nodes: unavailable", vim.log.levels.ERROR }))
vim.fn.delete(root, "rf")
print("ok: wiki navigation preserves list filtering, split selection, typed queries, cancellation, and errors")

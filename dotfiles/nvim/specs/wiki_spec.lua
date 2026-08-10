require("lib")

local original_system = vim.system
local calls = {}
local sync_results = {}
local async_callback
local killed_with

vim.system = function(command, options, callback)
  calls[#calls + 1] = { command = command, options = options }
  if callback then
    async_callback = callback
    return {
      kill = function(_, signal)
        killed_with = signal
      end,
    }
  end

  local result = table.remove(sync_results, 1)
  return {
    wait = function()
      return result
    end,
  }
end

package.loaded["modules.wiki.api"] = nil
local api = require("modules.wiki.api")

sync_results[#sync_results + 1] = { code = 0, stdout = "Zulu\nalpha\n\nBeta\n", stderr = "" }
local nodes = assert(api.list_nodes())
assert(vim.deep_equal(nodes, { "Beta", "Zulu", "alpha" }), "wiki nodes are not sorted")
assert(vim.deep_equal(calls[1].command, { "core", "wiki", "ls" }), "wiki list uses the wrong argv")
assert(calls[1].options.text, "wiki command does not request text output")
assert(calls[1].options.env.WIKI_ROOT:match("/brain/wiki$"), "wiki command has the wrong WIKI_ROOT")
assert(calls[1].options.env.TASK_ROOT == calls[1].options.env.WIKI_ROOT, "wiki roots differ")

sync_results[#sync_results + 1] = { code = 0, stdout = "Project B\nProject A\n", stderr = "" }
local projects = assert(api.list_projects())
assert(vim.deep_equal(projects, { "Project A", "Project B" }), "wiki projects are not sorted")
assert(
  vim.deep_equal(calls[2].command, { "core", "wiki", "ls", "--type", "project" }),
  "wiki project list uses the wrong argv"
)

sync_results[#sync_results + 1] = { code = 0, stdout = " /tmp/wiki node.plm\n", stderr = "" }
assert(api.resolve_node("wiki-node") == "/tmp/wiki node.plm", "wiki resolution does not trim its path")
assert(
  vim.deep_equal(calls[3].command, { "core", "wiki", "resolve", "wiki-node" }),
  "wiki resolution uses the wrong argv"
)

sync_results[#sync_results + 1] = { code = 2, stdout = "", stderr = "missing node\n" }
local missing_path, resolve_error = api.resolve_node("missing")
assert(missing_path == nil and resolve_error == "missing node", "wiki resolution hides command errors")

sync_results[#sync_results + 1] = { code = 0, stdout = "\n", stderr = "" }
local empty_path, empty_error = api.resolve_node("empty")
assert(empty_path == nil and empty_error == "core wiki returned an empty path", "wiki accepted an empty path")

local async_result
local cancel = api.list_nodes_async(function(entries, list_error)
  async_result = { entries = entries, error = list_error }
end)
async_callback({ code = 0, stdout = "second\nfirst\n", stderr = "" })
vim.wait(100, function()
  return async_result ~= nil
end)
assert(vim.deep_equal(async_result.entries, { "first", "second" }), "async wiki nodes are not sorted")
cancel()
assert(killed_with == 15, "async wiki cancellation did not stop the process")

local original_list_nodes_async = api.list_nodes_async
local completion_cancelled = false
local completion_calls = 0
api.list_nodes_async = function(callback)
  completion_calls = completion_calls + 1
  callback({ "project-one" })
  return function()
    completion_cancelled = true
  end
end

package.loaded["blink.cmp.types"] = { CompletionItemKind = { Reference = 18 } }
package.loaded["modules.wiki.blink-source"] = nil
local source = require("modules.wiki.blink-source").new()

local complete = function(line, cursor_col)
  local response
  local cancellation = source:get_completions({ line = line, pos = { row = 3, col = cursor_col } }, function(result)
    response = result
  end)
  return assert(response).items, cancellation
end

local items, cancellation = complete("[[pro", 5)
assert(#items == 1, "wiki completion did not return nodes")
assert(items[1].textEdit.newText == "project-one]]", "wiki completion did not add the closing brackets")
assert(
  vim.deep_equal(items[1].textEdit.range, {
    start = { line = 3, character = 2 },
    ["end"] = { line = 3, character = 5 },
  }),
  "wiki completion replaces the wrong text range"
)
cancellation()
assert(completion_cancelled, "wiki completion did not expose cancellation")

items = complete("[[pro]", 5)
assert(items[1].textEdit.newText == "project-one]", "wiki completion duplicated a single closing bracket")

items = complete("[[pro]]", 5)
assert(items[1].textEdit.newText == "project-one", "wiki completion duplicated existing closing brackets")

local calls_before_closed_link = completion_calls
items = complete("[[closed]] text", 15)
assert(#items == 0, "wiki completion appears outside an unmatched internal link")
assert(completion_calls == calls_before_closed_link, "wiki completion listed nodes outside an internal link")

local original_notify_once = vim.notify_once
local completion_warning
vim.notify_once = function(message, level)
  completion_warning = { message = message, level = level }
end
api.list_nodes_async = function(callback)
  callback(nil, "core unavailable")
  return function() end
end
items = complete("[[", 2)
assert(#items == 0, "failed wiki completion returned items")
assert(
  completion_warning.message == "Could not complete wiki links: core unavailable"
    and completion_warning.level == vim.log.levels.WARN,
  "failed wiki completion did not notify once"
)
vim.notify_once = original_notify_once

api.list_nodes_async = original_list_nodes_async
vim.system = original_system

print("ok: wiki API and Blink link completion")

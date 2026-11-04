require("lib")

local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/src", "p")
vim.fn.mkdir(root .. "/target/debug/build", "p")
vim.fn.mkdir(root .. "/targeted", "p")
vim.fn.writefile({ "before" }, root .. "/src/app.css")
vim.fn.writefile({ "before" }, root .. "/target/debug/build/output.css")
vim.fn.writefile({ "before" }, root .. "/targeted/app.css")

local changes = {}
local notifications = {}
vim.notify = function(message, level)
  table.insert(notifications, { message = message, level = level })
end

local client = {
  id = 1,
  name = "tailwindcss",
  capabilities = { workspace = { didChangeWatchedFiles = { dynamicRegistration = true } } },
  workspace_folders = { { uri = vim.uri_from_fname(root), name = "app" } },
  notify = function(_, method, params)
    assert(method == "workspace/didChangeWatchedFiles", method)
    vim.list_extend(changes, params.changes)
  end,
}
vim.lsp.get_client_by_id = function(id)
  if id == client.id then return client end
end

require("modules/language-support/lspconfig").setup()

local watchfiles = require("vim.lsp._watchfiles")
local has_change = function(path, change_type)
  for _, change in ipairs(changes) do
    if change.uri == vim.uri_from_fname(root .. path) and change.type == change_type then return true end
  end

  return false
end

local CREATED = vim.lsp.protocol.FileChangeType.Created
local CHANGED = vim.lsp.protocol.FileChangeType.Changed
local DELETED = vim.lsp.protocol.FileChangeType.Deleted
local ok, failure = xpcall(function()
  watchfiles.register({
    id = "workspace",
    registerOptions = { watchers = { { globPattern = "**/*" } } },
  }, client.id)

  vim.fn.writefile({ "after" }, root .. "/target/debug/build/output.css")
  vim.fn.mkdir(root .. "/target/debug/build/temporary", "p")
  vim.fn.delete(root .. "/target/debug/build/temporary", "d")
  vim.fn.writefile({ "after" }, root .. "/targeted/app.css")
  vim.fn.writefile({ "after" }, root .. "/src/app.css")
  assert(
    vim.wait(3000, function()
      return has_change("/src/app.css", CHANGED) and has_change("/targeted/app.css", CHANGED)
    end),
    "LSP watchers must report source edits, including directories whose names start with target"
  )

  for _, change in ipairs(changes) do
    assert(not change.uri:find("/target/", 1, true), "LSP watchers must exclude Rust build output")
  end

  assert(#notifications == 0, vim.inspect(notifications))

  vim.fn.mkdir(root .. "/src/components", "p")
  assert(
    vim.wait(3000, function()
      return has_change("/src/components", CREATED)
    end),
    "LSP watchers must discover new source directories"
  )

  local file = assert(vim.uv.fs_open(root .. "/src/components/button.css", "w", 420))
  assert(vim.uv.fs_close(file))
  assert(
    vim.wait(3000, function()
      return has_change("/src/components/button.css", CREATED)
    end),
    "LSP watchers must report files added inside new source directories: " .. vim.inspect(changes)
  )

  vim.fn.delete(root .. "/src/components/button.css")
  assert(
    vim.wait(3000, function()
      return has_change("/src/components/button.css", DELETED)
    end),
    "LSP watchers must report deleted source files"
  )

  vim.fn.mkdir(root .. "/src/temporary", "p")
  vim.fn.delete(root .. "/src/temporary", "d")
  vim.fn.delete(root .. "/src/components", "d")
  assert(
    vim.wait(3000, function()
      return has_change("/src/components", DELETED)
    end),
    "LSP watchers must keep reporting changes after temporary directories disappear"
  )
  assert(#notifications == 0, vim.inspect(notifications))

  watchfiles.register({
    id = "invalid-pattern",
    registerOptions = { watchers = { { globPattern = "[" } } },
  }, client.id)
  assert(
    vim.wait(1000, function()
      return #notifications > 0
    end),
    "LSP watcher failures must still be reported"
  )
  assert(notifications[1].level == vim.log.levels.ERROR, vim.inspect(notifications))
  assert(notifications[1].message:find("Invalid glob", 1, true), vim.inspect(notifications))
end, debug.traceback)

watchfiles.cancel(client.id)
vim.fn.delete(root, "rf")
assert(ok, failure)

print(
  "ok: LSP watchers skip Rust build output, track source changes, tolerate disappearing directories, and report errors"
)

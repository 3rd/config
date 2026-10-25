local root = vim.fn.tempname()
vim.env.XDG_STATE_HOME = root .. "/state"
vim.env.XDG_CACHE_HOME = root .. "/cache"
vim.fn.mkdir(root .. "/files", "p")
require("lib")
vim.opt.runtimepath:prepend(lib.env.dirs.vim.lazy.plugin)

local errors = {}
vim.notify = function(message, level)
  if level == vim.log.levels.ERROR then table.insert(errors, message) end
end

lib.lazy.setup(
  require("modules/workflow/file-management").plugins,
  vim.tbl_deep_extend("force", require("config.lazy"), {
    install = { missing = false },
    change_detection = { enabled = false },
    performance = { rtp = { reset = false } },
    rocks = { enabled = false },
    pkg = { enabled = false },
  })
)

assert(package.loaded["lsp-file-operations"] == nil, "file operations must stay lazy until the tree opens")

local api = require("nvim-tree.api")
api.tree.open({ path = root .. "/files" })

local messages = {}
local capabilities = {}
for _, method in ipairs({ "willCreate", "didCreate", "willRename", "didRename", "willDelete", "didDelete" }) do
  capabilities[method] = { filters = { { pattern = { glob = "**/*" } } } }
end

local client = {
  initialized = true,
  offset_encoding = "utf-16",
  server_capabilities = { workspace = { fileOperations = capabilities } },
  request_sync = function(_, method, params)
    table.insert(messages, { method = method, params = params })
    return { result = { changes = {} } }
  end,
  notify = function(_, method, params)
    table.insert(messages, { method = method, params = params })
    return true
  end,
}
local get_clients = vim.lsp.get_clients
local get_active_clients = vim.lsp.get_active_clients
vim.lsp.get_clients = function()
  return { client }
end
vim.lsp.get_active_clients = nil

local old_name = root .. "/files/old.lua"
local new_name = root .. "/files/new.lua"
local old_uri = vim.uri_from_fname(old_name)
local new_uri = vim.uri_from_fname(new_name)
local events = require("nvim-tree.events")
events._dispatch_will_create_file(old_name)
events._dispatch_file_created(old_name)
events._dispatch_will_rename_node(old_name, new_name)
events._dispatch_node_renamed(old_name, new_name)
events._dispatch_will_remove_file(new_name)
events._dispatch_file_removed(new_name)
vim.lsp.get_clients = get_clients
vim.lsp.get_active_clients = get_active_clients

local has_processed_callbacks = false
vim.schedule(function()
  has_processed_callbacks = true
end)
assert(vim.wait(1000, function()
  return has_processed_callbacks
end))
assert(#errors == 0, table.concat(errors, "\n"))
assert(
  vim.deep_equal(messages, {
    { method = "workspace/willCreateFiles", params = { files = { { uri = old_uri } } } },
    { method = "workspace/didCreateFiles", params = { files = { { uri = old_uri } } } },
    { method = "workspace/willRenameFiles", params = { files = { { oldUri = old_uri, newUri = new_uri } } } },
    { method = "workspace/didRenameFiles", params = { files = { { oldUri = old_uri, newUri = new_uri } } } },
    { method = "workspace/willDeleteFiles", params = { files = { { uri = new_uri } } } },
    { method = "workspace/didDeleteFiles", params = { files = { { uri = new_uri } } } },
  }),
  "file-tree create, rename, and delete events must reach LSP clients in order"
)

api.tree.close()
vim.loader.enable(false)
vim.fn.delete(root, "rf")
print("ok: file-operations startup and file-tree LSP events")

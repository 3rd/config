-- defaults
-- {
--   "compilerOptions": {
--     "checkJs": false,
--     "skipLibCheck": true,
--     "disableReferencedProjectLoad": true,
--     "disableSolutionSearching": true
--   },
--   "include": ["src"],
-- }

-- tsgo/tsc subdir mix
-- {
--   "extends": "../tsconfig.json",
--   "compilerOptions": {
--     "baseUrl": null,
--     "paths": {
--       "@/*": ["./../src/*"]
--     }
--   }
-- }

local inlay_hints = {
  parameterNames = { enabled = "literals", suppressWhenArgumentMatchesName = true },
  parameterTypes = { enabled = true },
  variableTypes = { enabled = true },
  propertyDeclarationTypes = { enabled = true },
  functionLikeReturnTypes = { enabled = true },
  enumMemberValues = { enabled = true },
}

local is_within = function(path, root)
  return path == root or vim.startswith(path, root .. "/")
end

local get_watcher_base = function(watcher)
  local pattern = watcher.globPattern
  if type(pattern) == "table" then
    local base_uri = type(pattern.baseUri) == "table" and pattern.baseUri.uri or pattern.baseUri
    return vim.uri_to_fname(base_uri)
  end
  if not vim.startswith(pattern, "/") then return nil end

  return vim.fs.dirname(pattern:match("^[^*?%[{]*") .. "_")
end

local is_inside_workspace = function(watcher, roots)
  local base = get_watcher_base(watcher)
  if base == nil then return true end

  return vim.iter(roots):any(function(root)
    return is_within(base, root)
  end)
end

local CREATED = vim.lsp.protocol.FileChangeType.Created
local CHANGED = vim.lsp.protocol.FileChangeType.Changed

-- tsc reloads a file it already holds only on "changed" and adds a new file only on "created". An atomic save
-- arrives as "created", and "changed" followed by "created" for the same file covers both cases.
local expand_created_changes = function(changes)
  local expanded = {}
  for _, change in ipairs(changes) do
    if change.type == CREATED then table.insert(expanded, { uri = change.uri, type = CHANGED }) end
    table.insert(expanded, change)
  end
  return expanded
end

local wrap_watched_file_notifications = function(client)
  local notify = client.notify
  client.notify = function(self, method, params)
    if method == "workspace/didChangeWatchedFiles" and params and params.changes then
      params = vim.tbl_extend("force", params, { changes = expand_created_changes(params.changes) })
    end
    return notify(self, method, params)
  end
end

local register_capability = function(err, params, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  local roots = vim.tbl_map(function(folder)
    return vim.uri_to_fname(folder.uri)
  end, client and client.workspace_folders or {})

  for _, registration in ipairs(params.registrations or {}) do
    if registration.method == "workspace/didChangeWatchedFiles" then
      registration.registerOptions.watchers = vim.tbl_filter(function(watcher)
        return is_inside_workspace(watcher, roots)
      end, registration.registerOptions.watchers)
    end
  end

  return vim.lsp.handlers["client/registerCapability"](err, params, ctx)
end

return {
  capabilities = {
    workspace = {
      -- tsc watches no files itself, so without client watching it never sees edits made outside Neovim
      didChangeWatchedFiles = { dynamicRegistration = true },
    },
  },
  handlers = {
    -- Neovim watches each registered tree recursively, and tsc also registers ancestors such as the whole
    -- synced tree and other repositories' node_modules, which cost tens of thousands of inotify watches each
    ["client/registerCapability"] = register_capability,
  },
  on_init = wrap_watched_file_notifications,
  settings = {
    ["js/ts"] = {
      customConfigFileName = "tsconfig.local.json",
      inlayHints = inlay_hints,
      preferences = {
        importModuleSpecifier = "shortest",
        useAliasesForRenames = true,
      },
    },
  },
}

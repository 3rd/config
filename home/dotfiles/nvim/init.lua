vim.loader.enable()

require("config")

-- https://github.com/neovim/neovim/issues/23291
local FSWATCH_EVENTS = {
  Created = 1,
  Updated = 2,
  Removed = 3,
  OwnerModified = 2,
  AttributeModified = 2,
  MovedFrom = 1,
  MovedTo = 3,
}
local function fswatch_output_handler(data, opts, callback)
  local d = vim.split(data, "%s+")
  local cpath = d[1]
  for i = 2, #d do
    if d[i] == "IsDir" or d[i] == "IsSymLink" or d[i] == "PlatformSpecific" then return end
  end
  if opts.include_pattern and opts.include_pattern:match(cpath) == nil then return end
  if opts.exclude_pattern and opts.exclude_pattern:match(cpath) ~= nil then return end
  for i = 2, #d do
    local e = FSWATCH_EVENTS[d[i]]
    if e then callback(cpath, e) end
  end
end
local function fswatch(path, opts, callback)
  local obj = vim.system({
    "fswatch",
    "--recursive",
    "--event-flags",
    "--exclude",
    "/.git/",
    path,
  }, {
    stdout = function(_, data)
      for line in vim.gsplit(data, "\n", { plain = true, trimempty = true }) do
        fswatch_output_handler(line, opts, callback)
      end
    end,
  })
  return function()
    obj:kill(2)
  end
end
require("vim.lsp._watchfiles")._watchfunc = fswatch

require("lib")

local node_provider = require("config/node-provider")

node_provider.setup()
assert(vim.g.node_host_prog == node_provider.host, "Node provider host does not use the configured tslib host")
assert(vim.fn.filereadable(node_provider.host) == 1, "configured Node provider host does not exist")

vim.cmd.source(vim.fn.stdpath("data") .. "/rplugin.vim")

local schedule = lib.node.chrono.to_schedule("tomorrow")
assert(type(schedule) == "string" and schedule:match("^%d%d%d%d%.%d%d%.%d%d$"), "Node schedule RPC returned no date")

print("ok: Node provider resolves Syslang schedules through the real RPC host")

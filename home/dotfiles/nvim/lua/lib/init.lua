require("lib/string")
require("lib/table")

local log = require("lib/log")

_G.log = log.create_logger({
  prefix = "[log]",
  formatter = log.default_log_formatter,
  handler = print,
  output_file = "/tmp/nvim-log.txt",
})

_G.throw = log.create_logger({
  prefix = "[error]",
  formatter = log.default_log_formatter,
  handler = error,
  output_file = "/tmp/nvim-log.txt",
})

_G.inspect = function(value)
  print(vim.inspect(value))
  return value
end

_G.lib = {
  buffer = require("lib/buffer"),
  env = require("lib/env"),
  fs = require("lib/fs"),
  is = require("lib/is"),
  lazy = require("lib/lazy"),
  log = log,
  map = require("lib/map"),
  module = require("lib/module"),
  path = require("lib/path"),
  random = require("lib/random"),
  shell = require("lib/shell"),
  ts = require("lib/treesitter"),
  ui = require("lib/ui"),
  node = require("lib/node"),
}

local _module = require("lib/module")
local buffer = require("lib/buffer")
local dev = require("lib/dev")
local env = require("lib/env")
local is = require("lib/is")
local log = require("lib/log")
local map = require("lib/map")
local options = require("lib/options")
local packer = require("lib/packer")
local path = require("lib/path")
local string = require("lib/string")
local table = require("lib/table")
local shell = require("lib/shell")

_G.log = dev.log
_G.throw = dev.throw
_G.inspect = dev.inspect

local module = {
  buffer = buffer,
  env = env,
  is = is,
  log = log,
  map = map,
  module = _module,
  options = options,
  packer = packer,
  path = path,
  string = string,
  table = table,
  shell = shell,
}

return module

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
vim.opt.runtimepath:prepend(root)
local bridge = require("bunvim")._vim
local codec = require("bunvim.rpc.codec")
local metadata = vim.json.decode(table.concat(vim.fn.readfile(root .. "/src/vim/generated/vim-functions.json"), "\n"))

local decode = function(value)
  return codec.decode(value, {
    decode_reference = function(reference)
      return reference
    end,
  })
end

local create_parser = function(context)
  return decode(
    bridge.call(
      context,
      { path = { "treesitter", "get_string_parser" } },
      codec.encode({ "return 9", "lua" }),
      metadata.functions["treesitter.get_string_parser"]
    )
  )
end

local read_language = function(context, reference)
  return decode(
    bridge.call(
      context,
      { reference = reference, method = "lang" },
      codec.encode({}),
      metadata.nativeClasses["vim.treesitter.LanguageTree"].methods.lang
    )
  )
end

local assert_rejected = function(callback, expected)
  local ok, err = pcall(callback)
  assert(not ok and tostring(err):find(expected, 1, true), tostring(err))
end

local run = function()
  local first = { owner = "first-plugin", scope = "first-invocation", channel = 0 }
  local same_owner = { owner = first.owner, scope = "second-invocation", channel = 0 }
  local other_owner = { owner = "second-plugin", scope = "third-invocation", channel = 0 }
  local parser = create_parser(first)
  assert(read_language(same_owner, parser) == "lua")
  assert_rejected(function()
    read_language(other_owner, parser)
  end, "another plugin")

  local second_parser = create_parser(same_owner)
  bridge.release_scope(first)
  assert_rejected(function()
    read_language(same_owner, parser)
  end, "disposed")
  assert(read_language(same_owner, second_parser) == "lua")

  bridge.dispose_reference(same_owner, second_parser)
  bridge.dispose_reference(same_owner, second_parser)
  assert_rejected(function()
    read_language(same_owner, second_parser)
  end, "disposed")

  local channel_parser = create_parser(same_owner)
  bridge.cancel_channel(0)
  assert_rejected(function()
    read_language(same_owner, channel_parser)
  end, "disposed")
end

local ok, failure = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(tostring(failure) .. "\n")
  vim.cmd("cquit 1")
end

print("Bunvim native-runtime passed")
vim.cmd("qa!")

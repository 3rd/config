local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
vim.opt.runtimepath:prepend(root)
local codec = require("bunvim.rpc.codec")

local run = function()
  local bytes = string.char(0, 128, 192, 255)
  local value = { text = "héllo 🐇", values = { codec.bytes(bytes), vim.NIL, false, 3 } }
  local decoded = codec.decode(codec.encode(value))
  assert(decoded.text == value.text and decoded.values[2] == vim.NIL and decoded.values[3] == false)
  assert(codec.bytes_value(decoded.values[1]) == bytes)
  assert(codec.decode(codec.encode(value), { should_unwrap_bytes = true }).values[1] == bytes)
  assert(codec.bytes_value(codec.decode(codec.encode(codec.bytes("")))) == "")
  local collision = { "bytes", "AIDA/w==" }
  assert(vim.deep_equal(codec.decode(codec.encode(collision)), collision))
  local native = {}
  local token = { scope = "scope", id = 1, type = "TSNode" }
  assert(codec.decode(codec.encode(codec.reference(token)), {
    decode_reference = function(reference)
      assert(vim.deep_equal(reference, token))
      return native
    end,
  }) == native)
  assert(not pcall(codec.decode, { "reference", "scope", 0, "TSNode" }))
  assert(not pcall(codec.decode, { "bytes", "AB==" }))
  assert(not pcall(codec.decode, { "bytes", "!!" }))
  assert(not pcall(codec.decode, { "object", { { "same", 1 }, { "same", 2 } } }))
  local cycle = {}
  cycle[1] = cycle
  assert(not pcall(codec.encode, cycle))
  assert(not pcall(codec.encode, math.huge))
  assert(not pcall(codec.bytes_value, { value = bytes }))

  local table_shapes = {
    setmetatable({ major = 1, minor = 2 }, {
      __index = function(_, key)
        if key == 1 then return 1 end
      end,
    }),
    setmetatable({ "one", "two" }, {
      __index = function()
        return "computed"
      end,
    }),
    { [1] = "one", [3] = "three" },
    { [2] = "two" },
    setmetatable({ [1] = "one", [3] = "three" }, getmetatable(vim.empty_dict())),
    vim.empty_dict(),
    { [vim.type_idx] = vim.types.array, [1] = "one", [3] = "three", ignored = 1 },
    { [vim.type_idx] = vim.types.dictionary, [1] = "ignored", named = 2 },
    { [vim.type_idx] = vim.types.float, [vim.val_idx] = 1.5 },
  }

  for _, shape in ipairs(table_shapes) do
    local native = vim.fn.deepcopy(shape)
    assert(vim.deep_equal(codec.decode(codec.encode(shape)), native), vim.inspect(shape))
  end

  for _, shape in ipairs({ { [0] = "zero" }, { [1] = "one", named = 2 }, { [1.5] = "fraction" } }) do
    assert(not pcall(codec.encode, shape))
  end
end

local ok, err = pcall(run)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end

io.stdout:write("Bunvim binary-codec passed\n")
vim.cmd("qa!")

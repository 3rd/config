local resolve = require("lib/path").resolve
local dev = require("lib/dev")

local escape = function(str)
  return vim.fn.shellescape(str)
end

local exec = function(str, input)
  return vim.fn.system(str, input)
end

local open = function(path)
  exec("xdg-open " .. escape(resolve(path)))
end

local write_file = function(path, data)
  local file = io.open(path, "w")
  if file then
    io.output(file)
    io.write(data)
    io.close(file)
  else
    throw("Could not open file for writing: " .. path)
  end
end

local append_file = function(path, data)
  local file = io.open(path, "a")
  if file then
    io.output(file)
    io.write(data)
    io.close(file)
  else
    throw("Could not open file for writing: " .. path)
  end
end

return {
  escape = escape,
  exec = exec,
  open = open,
  write_file = write_file,
  append_file = append_file,
}

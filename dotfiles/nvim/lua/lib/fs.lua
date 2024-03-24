local resolve = require("lib/path").resolve
local escape = require("lib/shell").escape

local file_exists = function(path)
  return vim.fn.filereadable(resolve(path)) == 1
end

local file_is_readable = function(path)
  return vim.fn.filereadable(resolve(path)) == 1
end

local file_is_writable = function(path)
  return vim.fn.filewritable(resolve(path)) == 1
end

local file_is_executable = function(path)
  return vim.fn.executable(resolve(path)) == 1
end

local file_read = function(path)
  local file = io.open(resolve(path), "r")
  if file then
    io.input(file)
    local data = io.read("*all")
    io.close(file)
    return data
  else
    throw("Could not open file for reading: " .. path)
  end
end

local file_write = function(path, data)
  local file = io.open(resolve(path), "w")
  if file then
    io.output(file)
    io.write(data)
    io.close(file)
  else
    throw("Could not open file for writing: " .. path)
  end
end

local file_append = function(path, data)
  local file = io.open(resolve(path), "a")
  if file then
    io.output(file)
    io.write(data)
    io.close(file)
  else
    throw("Could not open file for appending: " .. path)
  end
end

local directory_exists = function(path)
  return vim.fn.isdirectory(resolve(path)) == 1
end

local directory_create = function(path)
  return os.execute("mkdir -p " .. escape(resolve(path)))
end

local exists = function(path)
  return file_exists(path) or directory_exists(path)
end

return {
  file = {
    exists = file_exists,
    is_readable = file_is_readable,
    is_writable = file_is_writable,
    is_executable = file_is_executable,
    read = file_read,
    write = file_write,
    append = file_append,
  },
  directory = {
    exists = directory_exists,
    create = directory_create,
  },
  exists = exists,
}

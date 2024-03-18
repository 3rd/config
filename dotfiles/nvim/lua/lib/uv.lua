-- https://neovim.io/doc/user/luvref.html#luv-timer-handle

local setTimeout = function(callback, timeout)
  timeout = timeout or 0
  local timer = vim.uv.new_timer()
  timer:start(timeout, 0, function()
    timer:stop()
    timer:close()
    vim.schedule(callback)
  end)
  return timer
end

local setInterval = function(callback, interval)
  interval = interval or 0
  local timer = vim.uv.new_timer()
  timer:start(interval, interval, function()
    vim.schedule(callback)
  end)
  return timer
end

local clearInterval = function(timer)
  timer:stop()
  timer:close()
end

return {
  setTimeout = setTimeout,
  setInterval = setInterval,
  clearInterval = clearInterval,
}

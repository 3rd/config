math.randomseed(os.clock() ^ 5)

local module = {
  string = function(length)
    length = length or 32
    local res = ""
    for _ = 1, length do
      res = res .. string.char(math.random(97, 122))
    end
    return res
  end,
}

return module

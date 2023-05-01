---@class EventBus
---@field subscriptions table<string, function[]>
local EventBus = {
  subscriptions = {},
}

function EventBus:new()
  return setmetatable({
    subscriptions = {},
  }, self)
end

---@param name string
---@param callback function
function EventBus:on(name, callback)
  self.subscriptions[name] = self.subscriptions[name] or {}
  table.insert(self.subscriptions[name], callback)
end

---@param name string
---@param callback function
function EventBus:off(name, callback)
  if self.subscriptions[name] then
    for i, v in ipairs(self.subscriptions[name]) do
      if v == callback then
        table.remove(self.subscriptions[name], i)
        break
      end
    end
  end
end

---@param name string
---@param ... any
function EventBus:emit(name, ...)
  if self.subscriptions[name] then
    for _, callback in ipairs(self.subscriptions[name]) do
      callback(...)
    end
  end
end

return EventBus

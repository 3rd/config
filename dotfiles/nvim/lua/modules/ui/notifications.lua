-- https://github.com/rmagatti/goto-preview/issues/129
local setup = function()
  local notify_original = vim.notify
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.notify = function(msg, ...)
    if
      msg
      and (
        msg:match("position_encoding param is required")
        or msg:match("Defaulting to position encoding of the first client")
        or msg:match("multiple different client offset_encodings")
      )
    then
      return
    end
    return notify_original(msg, ...)
  end
end
setup()

return lib.module.create({
  name = "ui/notifications",
  hosts = "*",
})

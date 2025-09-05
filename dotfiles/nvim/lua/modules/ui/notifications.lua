return lib.module.create({
  name = "ui/notifications",
  hosts = "*",
  plugins = {
    {
      "rcarriga/nvim-notify",
      event = "VeryLazy",
      config = function()
        local notify = require("notify")
        local colors = require("config/colors-hex")
        notify.setup({
          timeout = 2000,
          max_width = function()
            return math.floor(vim.o.columns * 0.6)
          end,
        })
        -- https://github.com/rmagatti/goto-preview/issues/129
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
          return notify(msg, ...)
        end
      end,
    },
  },
})

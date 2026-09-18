return lib.module.create({
  name = "ui/notifications",
  hosts = "*",
  actions = {
    {
      "n",
      "Notifications: Search history",
      function()
        local telescope = require("telescope")
        telescope.load_extension("notify")
        telescope.extensions.notify.notify()
      end,
    },
  },
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
        vim.notify = function(msg, level, opts)
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
          opts = vim.tbl_extend("keep", opts or {}, {
            timeout = (level == vim.log.levels.ERROR or level == "error") and 10000
              or (level == vim.log.levels.WARN or level == "warn") and 6000
              or 2000,
          })
          return notify(msg, level, opts)
        end
      end,
    },
  },
})

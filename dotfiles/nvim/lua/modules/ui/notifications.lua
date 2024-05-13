local setup_nvim_notify = function()
  local notify = require("notify")
  notify.setup({
    background_colour = "#000000",
    fps = 30,
    icons = {
      DEBUG = "",
      ERROR = "",
      INFO = "",
      TRACE = "✎",
      WARN = "",
    },
    level = 2,
    max_width = 80,
    render = "minimal",
    stages = "fade",
    -- stages = "fade_in_slide_out",
    timeout = 5000,
    top_down = true,
  })
  vim.notify = notify
end

return lib.module.create({
  name = "ui/notifications",
  hosts = "*",
  plugins = {
    {
      "rcarriga/nvim-notify",
      event = "VeryLazy",
      config = setup_nvim_notify,
    },
  },
})

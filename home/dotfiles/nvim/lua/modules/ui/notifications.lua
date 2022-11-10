local setup_nvim_notify = function()
  local notify = require("notify")
  notify.setup({
    background_colour = "#000000",
  })
end

return require("lib").module.create({
  name = "ui/notifications",
  plugins = {
    { "rcarriga/nvim-notify", config = setup_nvim_notify },
  },
})

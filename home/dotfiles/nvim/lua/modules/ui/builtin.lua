local setup = function()
  -- TODO: override vim.ui.input
end

return require("lib").module.create({
  name = "ui/builtin",
  setup = setup,
})

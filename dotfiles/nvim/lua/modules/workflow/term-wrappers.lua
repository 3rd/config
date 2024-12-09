local scooter = function()
  lib.term.open({ cmd = "scooter" })
end

return lib.module.create({
  name = "term-wrappers",
  hosts = "*",
  mappings = {
    { "n", "<leader>tf", scooter, "Scooter" },
  },
})

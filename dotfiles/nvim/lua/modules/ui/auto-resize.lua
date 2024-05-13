return lib.module.create({
  name = "ui/auto-resize",
  hosts = "*",
  mappings = {
    { "n", "==", ":tabdo wincmd =<cr>" },
  },
})

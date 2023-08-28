return lib.module.create({
  name = "ui/auto-resize",
  mappings = {
    { "n", "==", ":tabdo wincmd =<cr>" },
  },
})

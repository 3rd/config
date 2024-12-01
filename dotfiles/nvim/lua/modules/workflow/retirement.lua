return lib.module.create({
  name = "workflow/retirement",
  hosts = "*",
  plugins = {
    {
      "chrisgrieser/nvim-early-retirement",
      opts = {
        retirementAgeMins = 20,
        ignoredFiletypes = {},
        ignoreFilenamePattern = "",
        ignoreAltFile = true,
        minimumBufferNum = 10,
        ignoreUnsavedChangesBufs = true,
        ignoreSpecialBuftypes = true,
        ignoreVisibleBufs = true,
        ignoreUnloadedBufs = false,
        notificationOnAutoClose = false,
        deleteBufferWhenFileDeleted = false,
      },
    },
  },
})

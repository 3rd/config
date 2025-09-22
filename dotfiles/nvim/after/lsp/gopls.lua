return {
  cmd = { "gopls", "-remote=auto", "-remote.debug=:0" },
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
        unreachable = false,
        ST1003 = false,
      },
      codelenses = {
        generate = true,
        gc_details = true,
        test = true,
        tidy = true,
      },
      usePlaceholders = true,
      completeUnimported = true,
      staticcheck = true,
      matcher = "fuzzy",
      diagnosticsDelay = "500ms",
      symbolMatcher = "fuzzy",
      gofumpt = false,
      buildFlags = { "-tags", "integration" },
    },
  },
}

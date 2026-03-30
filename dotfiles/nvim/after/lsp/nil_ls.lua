---@type vim.lsp.Config
return {
  settings = {
    ["nil"] = {
      nix = {
        binary = "nix",
        maxMemoryMB = vim.NIL,
        flake = {
          autoEvalInputs = true,
          autoArchive = true,
        },
      },
    },
  },
}

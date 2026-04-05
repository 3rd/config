---@type vim.lsp.Config
return {
  settings = {
    ["nil"] = {
      nix = {
        binary = "nix",
        maxMemoryMB = 8 * 1024,
        flake = {
          autoEvalInputs = true,
          autoArchive = true,
          nixpkgsInputName = vim.NIL,
        },
      },
    },
  },
}

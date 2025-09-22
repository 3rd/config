return {
  ["nil"] = {
    nix = {
      binary = "nix",
      maxMemoryMB = nil,
      flake = {
        autoEvalInputs = true,
        autoArchive = true,
      },
    },
  },
}

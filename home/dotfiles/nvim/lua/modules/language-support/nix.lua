local null_ls = require("null-ls")

return lib.module.create({
  name = "language-support/nix",
  hooks = {
    treesitter = {
      "nix",
    },
    lspconfig = {
      nixd = {},
    },
    null = {
      null_ls.builtins.diagnostics.statix,
      null_ls.builtins.code_actions.statix,
      null_ls.builtins.diagnostics.deadnix,
      null_ls.builtins.formatting.nixfmt.with({ extra_args = { "--width", "80" } }),
    },
  },
})

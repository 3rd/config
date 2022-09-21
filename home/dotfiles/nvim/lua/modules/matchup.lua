return require("lib").module.create({
  name = "matchup",
  plugins = {
    {
      "andymass/vim-matchup",
      ft = { "html", "typescriptreact", "javascriptreact", "vue", "svelte", "astro" },
    },
  },
})

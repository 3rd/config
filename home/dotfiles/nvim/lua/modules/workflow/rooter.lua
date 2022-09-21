local setup = function()
  vim.g.rooter_patterns = { ".root", ".git" }
  vim.g.rooter_resolve_links = 1
  vim.g.rooter_silent_chdir = 1
end

return require("lib").module.create({
  name = "workflow/rooter",
  plugins = {
    { "airblade/vim-rooter", config = setup },
  },
})

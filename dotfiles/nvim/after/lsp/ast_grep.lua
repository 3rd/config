---@type vim.lsp.Config
return {
  enabled = false,
  cmd = { "ast-grep", "lsp" },
  single_file_support = false,
  root_markers = { "sgconfig.yml" },
  root_dir = function(bufnr, on_dir)
    if vim.fs.root(bufnr, "sgconfig.yml") then
      --
      on_dir(vim.fn.getcwd())
    end
  end,
}

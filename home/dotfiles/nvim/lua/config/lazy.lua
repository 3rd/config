local lazy_root_path = lib.env.dirs.vim.lazy.root

return {
  root = lazy_root_path,
  defaults = { lazy = true },
  git = { log = { "-5" } },
  ui = { border = "rounded" },
  performance = {
    rtp = {
      reset = false,
      paths = {},
      disabled_plugins = {
        -- "matchit",
        -- "matchparen",
        -- "tutor",
        "gzip",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "zipPlugin",
      },
    },
  },
}

local lazy_root_path = lib.env.dirs.vim.lazy.root
local lazy_rtp_reset = vim.g.lazy_rtp_reset
if lazy_rtp_reset == nil then lazy_rtp_reset = true end

return {
  root = lazy_root_path,
  defaults = { lazy = true },
  git = { log = { "-5" } },
  ui = { border = "rounded" },
  change_detection = {
    enabled = false,
    notify = false,
  },
  rocks = { enabled = false },
  performance = {
    rtp = {
      reset = lazy_rtp_reset,
      paths = vim.g.lazy_rtp_paths or {},
      disabled_plugins = {
        "matchit",
        "matchparen",
        "tutor",
        "gzip",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "zipPlugin",
      },
    },
  },
}

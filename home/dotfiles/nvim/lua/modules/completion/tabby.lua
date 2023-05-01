return lib.module.create({
  enabled = false,
  name = "completion/tabby",
  plugins = {
    {
      "TabbyML/tabby",
      lazy = false,
      init = function(plugin)
        vim.g.tabby_server_url = "http://127.0.0.1:5000"
        vim.g.tabby_filetype_to_languages = {
          typescriptreact = "typescript",
        }
        require("lazy.core.loader").ftdetect(plugin.dir .. "/clients/vim")
      end,
      config = function(plugin)
        vim.opt.rtp:append(plugin.dir .. "/clients/vim")
        require("lazy.core.loader").packadd(plugin.dir .. "/clients/vim")
      end,
    },
  },
})

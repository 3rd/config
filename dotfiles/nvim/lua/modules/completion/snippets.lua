return lib.module.create({
  name = "completion/snippets",
  hosts = "*",
  plugins = {
    {
      "L3MON4D3/LuaSnip",
      commit = "1e57afa005fcd7c8d8c31ec896cbaf9157320413",
      config = function()
        local luasnip = require("luasnip")
        luasnip.filetype_extend("all", { "_" })

        -- load
        require("luasnip.loaders.from_snipmate").load({
          path = { lib.path.resolve(lib.env.dirs.vim.config .. "/snippets") },
        })

        -- cancel snippet - https://github.com/L3MON4D3/LuaSnip/issues/656
        vim.api.nvim_create_autocmd("ModeChanged", {
          group = vim.api.nvim_create_augroup("snippet-cancel", {}),
          pattern = { "s:n", "i:*" },
          callback = function(evt)
            if luasnip.session and luasnip.session.current_nodes[evt.buf] and not luasnip.session.jump_active then
              luasnip.unlink_current()
            end
          end,
        })
      end,
    },
  },
})

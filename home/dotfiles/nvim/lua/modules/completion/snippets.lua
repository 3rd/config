local setup_luasnip = function()
  local luasnip = require("luasnip")
  local lib = require("lib")

  -- map global snippets
  luasnip.filetype_extend("all", { "_" })

  -- load snippets
  require("luasnip.loaders.from_snipmate").load({
    path = { lib.path.resolve(lib.env.dirs.config .. "/snippets") },
  })

  -- cancel current session on mode change
  local augroup = vim.api.nvim_create_augroup("luasnip-mode-change-cancel", { clear = true })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = augroup,
    pattern = { "i:n" },
    callback = function()
      if
        luasnip.session.current_nodes[vim.api.nvim_get_current_buf()]
        and not luasnip.session.jump_active
      then
        luasnip.unlink_current()
      end
    end,
  })
end

return require("lib").module.create({
  name = "completion/snippets",
  plugins = { { "L3MON4D3/LuaSnip", config = setup_luasnip } },
})

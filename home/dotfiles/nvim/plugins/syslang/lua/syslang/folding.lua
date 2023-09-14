-- https://github.com/neovim/neovim/blob/master/runtime/lua/vim/treesitter/languagetree.lua

local restore_view = function()
  vim.cmd("silent! loadview")
end

local save_view = function()
  vim.cmd("silent! mkview")
end

-- local lang_map = {}
-- local disable_folds = function(language)
--   local query = vim.treesitter.query.get(language, "folds")
--   lang_map[language] = query
--   vim.treesitter.query.set(language, "folds", "")
--   vim._foldupdate()
-- end
-- _G.disable_folds = disable_folds

local setup = function()
  -- vim.opt.foldmethod = "expr"
  -- vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"

  local group = vim.api.nvim_create_augroup("SyslangFoldPersistence", { clear = true })
  local bufnr = vim.api.nvim_get_current_buf()

  -- save/restore view
  vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
    group = group,
    buffer = bufnr,
    callback = restore_view,
  })
  vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
    group = group,
    buffer = bufnr,
    callback = save_view,
  })
  -- vim.cmd("silent! loadview")

  -- prevent folding in injected regions
  -- https://github.com/neovim/neovim/blob/9fc321c9768d1a18893e14f46b0ebacef1be1db4/runtime/lua/vim/treesitter/_fold.lua#L157C21-L157C21
  -- local bufnr = vim.api.nvim_get_current_buf()
  -- local parser = vim.treesitter.get_parser(bufnr)
  -- if parser == nil then error("no parser") end
  -- parser:parse(true)

  -- parser:for_each_tree(function(tree, ltree)
  --   local lang = ltree:lang()
  --   log("disable_folds", lang)
  --   local query = vim.treesitter.query.get(lang, "folds")
  --   if query ~= nil then disable_folds(lang) end
  -- end)

  -- local disable_injected_folds = function()
  --   parser:for_each_child(function(_, lang)
  --     if lang_map[lang] then return end
  --   end)
  -- end
  --
  -- local attach = function()
  --   parser = vim.treesitter.get_parser(bufnr, "syslang")
  --   parser:register_cbs({
  --     on_changedtree = function()
  --       disable_injected_folds()
  --     end,
  --   })
  --   disable_injected_folds()
  -- end
  --
  -- local detach = function()
  --   parser:destroy()
  -- end
end

return {
  setup = setup,
}

local function lua_rtp()
  local runtime_path = vim.split(package.path, ";")
  table.insert(runtime_path, "lua/?.lua")
  table.insert(runtime_path, "lua/?/init.lua")
  return runtime_path
end

vim.lsp.config["luals"] = {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { ".root", ".luarc.json", ".luarc.jsonc" },
  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT",
        path = lua_rtp(),
      },
      workspace = {
        library = {
          vim.env.VIMRUNTIME,
          -- [vim.fn.expand("$VIMRUNTIME/lua")] = true,
          -- [vim.fn.stdpath("config")] = true,
          -- [".luarc.json"] = true,
          -- [vim.fn.expand("$VIMRUNTIME/lua")] = true,
          -- [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
          -- [vim.fn.stdpath("config") .. "/lua"] = true,
          -- [vim.fn.expand("$PWD/lua")] = true,
        },
        checkThirdParty = false,
        ignoreDir = { ".git", "node_modules", "linters", "plugins" },
        maxPreload = 500,
        preloadFileSize = 500,
      },
      completion = { callSnippet = "Replace" },
      diagnostics = {
        globals = { "vim", "describe", "it", "before_each", "after_each" },
        disable = { "missing-fields", "unused-local" },
        unusedLocalExclude = { "_*" },
      },
      hint = { enable = true },
      semantic = { keyword = true },
      telemetry = {
        enable = false,
      },
    },
  },
  handlers = {
    -- always go to the first definition
    ["textDocument/definition"] = function(err, result, ...)
      if vim.islist(result) or type(result) == "table" then result = result[1] end
      vim.lsp.handlers["textDocument/definition"](err, result, ...)
    end,
  },
}
vim.lsp.enable("luals")

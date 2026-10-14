local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
local M = {}

M.setup = function()
  require("bunvim").setup({
    plugins = {
      chrono = { path = root .. "/src/chrono/index.ts" },
    },
  })
end

return M

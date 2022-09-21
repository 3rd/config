local setup = {
  twilight = function()
    require("twilight").setup({})
    -- vim.api.nvim_create_autocmd("BufEnter", { callback = function() vim.cmd("TwilightEnable") end, })
  end,
  zoom = function()
    require("neo-zoom").setup({
      left_ratio = 0,
      top_ratio = 0,
      width_ratio = 1,
      height_ratio = 1,
      border = "double",
    })
  end,
}

return require("lib").module.create({
  name = "ui/zen",
  plugins = {
    { "folke/twilight.nvim", config = setup.twilight },
    { "nyngwang/NeoZoom.lua", config = setup.zoom },
  },
  mappings = {
    { "n", "<leader>f", ":NeoZoom<cr>" },
  },
})

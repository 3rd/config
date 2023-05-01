local setup = function()
  vim.g.matchup_matchparen_offscreen = { method = "popup" }

  vim.g.matchup_surround_enabled = 0
  vim.g.matchup_motion_enabled = 0
  vim.g.matchup_text_obj_enabled = 1
end

-- local setup_sentiment = function()
--   require("sentiment").setup({
--     included_buftypes = { [""] = true },
--     excluded_filetypes = {},
--     included_modes = { n = true, i = true },
--     limit = 200,
--     pairs = {
--       { "(", ")" },
--       { "{", "}" },
--       { "[", "]" },
--     },
--   })
-- end

return lib.module.create({
  name = "workflow/matchup",
  plugins = {
    {
      "andymass/vim-matchup",
      lazy = false,
      -- event = "VeryLazy",
      -- keys = { "%" },
      config = setup,
    },
    -- {
    --   "utilyre/sentiment.nvim",
    --   event = "VeryLazy",
    --   config = setup_sentiment,
    -- },
  },
})

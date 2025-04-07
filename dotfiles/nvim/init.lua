vim.loader.enable(true)
-- vim.loader.reset()

if vim.env.PROF then
  local snacks_path = vim.fn.stdpath("data") .. "/lazy/snacks.nvim"
  vim.opt.rtp:append(snacks_path)
  local has_snacks, snacks = pcall(require, "snacks.profiler")
  if has_snacks then
    snacks.startup({
      startup = {
        event = "VeryLazy", -- "VimEnter", "UIEnter", "VeryLazy",
      },
    })
  end
end

require("config")

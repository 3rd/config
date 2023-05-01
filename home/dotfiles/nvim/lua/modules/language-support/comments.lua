local setup = function()
  require("Comment").setup({
    mappings = {
      basic = true,
      extra = true,
      extended = false,
    },
    pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
  })
end

return lib.module.create({
  name = "language-support/comments",
  plugins = {
    {
      "numToStr/Comment.nvim",
      event = "VeryLazy",
      dependencies = { "JoosepAlviste/nvim-ts-context-commentstring" },
      config = setup,
    },
  },
})

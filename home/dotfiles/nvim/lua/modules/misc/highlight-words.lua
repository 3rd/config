return lib.module.create({
  name = "misc/highlight-words",
  plugins = {
    {
      "dvoytik/hi-my-words.nvim",
      -- event = "VeryLazy",
      config = function()
        require("hi-my-words").setup()
        lib.map.map("n", "<space>m", ":HiMyWordsToggle<CR>", "Toggle word highlight")
        lib.map.map("n", "<space>M", ":HiMyWordsClear<CR>", "Clear word highlights")
      end,
      keys = {
        "<space>m",
        "<space>M",
      },
    },
  },
})

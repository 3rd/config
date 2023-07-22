return lib.module.create({
  name = "misc/highlight-words",
  plugins = {
    {
      event = "VeryLazy",
      "dvoytik/hi-my-words.nvim",
      config = function()
        require("hi-my-words").setup()
        lib.map.map("n", "<space>m", ":HiMyWordsToggle<CR>", "Toggle word highlight")
        lib.map.map("n", "<space>M", ":HiMyWordsClear<CR>", "Clear word highlights")
      end,
    },
  },
})

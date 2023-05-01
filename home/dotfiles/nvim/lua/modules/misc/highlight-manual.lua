local setup_hi_my_words = function()
  require("hi-my-words").setup()
  lib.map.map("n", "<space>m", ":HiMyWordsToggle<CR>", "Toggle word highlight")
  lib.map.map("n", "<space>M", ":HiMyWordsClear<CR>", "Clear highlights")
end

return lib.module.create({
  name = "misc/highlight-manual",
  plugins = {
    {
      "dvoytik/hi-my-words.nvim",
      config = setup_hi_my_words,
      keys = { "<space>m", "<space>M" },
    },
  },
})

return lib.module.create({
  name = "lab",
  hosts = { "spaceship", "macbook" },
  -- enabled = false,
  plugins = {
    {
      "0x100101/lab.nvim",
      event = "VeryLazy",
      build = "cd js && npm ci",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        require("lab").setup({
          code_runner = { enabled = true },
          quick_data = { enabled = false },
        })
      end,
      keys = {
        { "<F9>", ":Lab code run<CR>", desc = "Run code" },
      },
    },
  },
  actions = {
    { "n", "Lab: Run code", ":Lab code run<CR>" },
    { "n", "Lab: Stop", ":Lab code stop<CR>" },
    { "n", "Lab: Panel", ":Lab code panel<CR>" },
  },
})

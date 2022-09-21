local setup_lab = function()
  require("lab").setup({})
end

return require("lib").module.create({
  enabled = false,
  name = "code-runner",
  plugins = {
    {
      "https://github.com/0x100101/lab.nvim",
      requires = { "nvim-lua/plenary.nvim" },
      run = "cd js && npm ci",
      config = setup_lab,
    },
  },
  mappings = {
    { "n", "<F4>", ":Lab code stop<cr>" },
    { "n", "<F5>", ":Lab code run<cr>" },
    { "n", "<F6>", ":Lab code panel<cr>" },
  },
})

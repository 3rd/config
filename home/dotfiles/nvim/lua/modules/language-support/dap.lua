local setup = function() end

return require("lib").module.create({
  name = "language-support/dap",
  plugins = {
    {
      "mfussenegger/nvim-dap",
      requires = {
        "theHamsta/nvim-dap-virtual-text",
        "rcarriga/nvim-dap-ui",
      },
      config = setup,
    },
  },
})

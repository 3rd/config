local setup = function() end

return lib.module.create({
  name = "language-support/debugger",
  plugins = {
    {
      "mfussenegger/nvim-dap",
      dependencies = {
        "theHamsta/nvim-dap-virtual-text",
        "rcarriga/nvim-dap-ui",
      },
      config = setup,
    },
  },
})

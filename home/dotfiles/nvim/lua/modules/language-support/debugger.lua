local setup = function()
  local dap = require("dap")
  local dapui = require("dapui")
  local dap_vt = require("nvim-dap-virtual-text")

  -- adapters
  dap.adapters = vim.tbl_extend("force", dap.adapters, {
    node2 = {
      type = "executable",
      command = "node",
      args = { vim.fn.stdpath("data") .. "/mason/packages/node-debug2-adapter/out/src/nodeDebug.js" },
    },
    chrome = {
      type = "executable",
      runtimeExecutable = "/run/current-system/sw/bin/google-chrome-stable",
      runtimeArgs = { "--remote-debugging-port=9229" },
      command = "node",
      args = { vim.fn.stdpath("data") .. "/mason/packages/chrome-debug-adapter/out/src/chromeDebug.js" },
    },
    delve = {
      type = "server",
      port = "${port}",
      executable = {
        command = vim.fn.stdpath("data") .. "/mason/bin/dlv",
        args = { "dap", "-l", "127.0.0.1:${port}" },
      },
    },
  })

  -- configs
  dap.configurations.typescript = {
    -- node --inspect-brk target.js
    {
      name = "node2 (attach)",
      type = "node2",
      request = "attach",
      program = "${file}",
      cwd = vim.fn.expand("%:p:h"),
      sourceMaps = true,
      protocol = "inspector",
      processId = require("dap.utils").pick_process,
    },
    {
      name = "node2 (launch file)",
      type = "node2",
      request = "launch",
      protocol = "inspector",
      cwd = "${workspaceFolder}",
      program = "${file}",
      sourceMaps = true,
      skipFiles = { "<node_internals>/**", "node_modules/**" },
    },
    {
      name = "node2 (npm run dev)",
      type = "node2",
      request = "launch",
      protocol = "inspector",
      runtimeExecutable = "npm",
      runtimeArgs = { "run", "dev" },
      cwd = vim.fn.getcwd(),
      sourceMaps = true,
      skipFiles = { "<node_internals>/**", "node_modules/**" },
    },
    {
      name = "node2 (jest)",
      type = "node2",
      request = "launch",
      protocol = "inspector",
      runtimeExecutable = "node",
      runtimeArgs = { "--inspect-brk", "${workspaceFolder}/node_modules/.bin/jest" },
      args = { "${file}", "--runInBand", "--no-cache", "--coverage", "false" },
      rootPath = "${workspaceFolder}",
      cwd = "${workspaceFolder}",
      console = "integratedTerminal",
      internalConsoleOptions = "neverOpen",
      sourceMaps = "inline",
      port = 9229,
      skipFiles = { "<node_internals>/**", "node_modules/**" },
    },
  }
  dap.configurations.javascript = dap.configurations.typescript

  dap.configurations.typescriptreact = vim.tbl_extend("force", {}, dap.configurations.typescript, {
    {
      name = "chrome (launch :3000)",
      type = "chrome",
      request = "launch",
      protocol = "inspector",
      port = 9229,
      runtimeExecutable = "/run/current-system/sw/bin/google-chrome-stable",
      runtimeArgs = { "--remote-debugging-port=9229", "--user-data-dir='/tmp/debug'", "http://localhost:3000" },
      sourceMaps = true,
      sourceMapPathOverrides = {
        -- next
        ["webpack://_N_E/./*"] = "${webRoot}/*",
        ["webpack:///./*"] = "${webRoot}/*",
      },
      skipFiles = { "${workspaceFolder}/node_modules/**/*.js", "**/@vite/*", "**/src/client/*", "**/src/*" },
      webRoot = "${workspaceFolder}",
    },
    -- google-chrome-stable  --remote-debugging-port=9229 --user-data-dir="/tmp/debug"
    {
      name = "chrome (attach)",
      type = "chrome",
      request = "attach",
      protocol = "inspector",
      port = 9229,
      skipFiles = { "${workspaceFolder}/node_modules/**/*.js", "**/@vite/*", "**/src/client/*", "**/src/*" },
      webRoot = "${workspaceFolder}",
    },
  })
  dap.configurations.javascriptreact = dap.configurations.typescriptreact

  dap.configurations.go = {
    {
      name = "run",
      type = "delve",
      request = "launch",
      program = "${file}",
    },
    {
      name = "test",
      type = "delve",
      request = "launch",
      mode = "test",
      program = "${file}",
    },
    {
      name = "test (go.mod)",
      type = "delve",
      request = "launch",
      mode = "test",
      program = "./${relativeFileDirname}",
    },
  }

  dap_vt.setup({})

  dapui.setup({
    expand_lines = true,
    floating = {
      border = "rounded",
      max_height = 0.8,
      max_width = 0.5,
      mappings = { close = { "q", "<esc>" } },
    },
    icons = { expanded = "▾", collapsed = "▸", circular = "◌" },
    -- layouts = {},
    -- mappings = {},
  })

  dap.listeners.after.event_initialized["dapui_config"] = function()
    -- dapui.open()
    dapui.open({ reset = true })
  end
  dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
  end
  dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
  end

  vim.fn.sign_define("DapBreakpoint", { text = " ", texthl = "", linehl = "", numhl = "" })
  vim.fn.sign_define("DapBreakpointRejected", { text = " ", texthl = "DiagnosticError", linehl = "", numhl = "" })
  vim.fn.sign_define("DapBreakpointCondition", { text = " ", texthl = "", linehl = "", numhl = "" })
  vim.fn.sign_define(
    "DapStopped",
    { text = " ", texthl = "DiagnosticWarn", linehl = "DapStoppedLine", numhl = "DapStoppedLine" }
  )
  vim.fn.sign_define("DapLogPoint", { text = ".>", texthl = "", linehl = "", numhl = "" })

  vim.keymap.set("n", "<leader>b", function()
    require("dap").toggle_breakpoint()
  end)
  vim.keymap.set("n", "<F1>", function()
    require("dap").continue()
  end)
  vim.keymap.set("n", "<leader>dq", function()
    require("dap").terminate()
  end)
  vim.keymap.set("n", "<F2>", function()
    require("dap").step_over()
  end)
  vim.keymap.set("n", "<F3>", function()
    require("dap").step_into()
  end)
  vim.keymap.set("n", "<F4>", function()
    require("dap").step_out()
  end)
end

return lib.module.create({
  name = "language-support/debugger",
  plugins = {
    {
      "mfussenegger/nvim-dap",
      event = "VeryLazy",
      dependencies = {
        "williamboman/mason.nvim",
        "theHamsta/nvim-dap-virtual-text",
        "rcarriga/nvim-dap-ui",
      },
      config = setup,
    },
  },
})

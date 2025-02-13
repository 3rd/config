return lib.module.create({
  name = "debug",
  hosts = "*",
  plugins = {
    {
      "mfussenegger/nvim-dap",
      event = "VeryLazy",
      dependencies = {
        { "williamboman/mason.nvim" },
        { "jay-babu/mason-nvim-dap.nvim" },
        {
          "rcarriga/nvim-dap-ui",
          dependencies = { "nvim-neotest/nvim-nio" },
          opts = {},
        },
        {
          "igorlfs/nvim-dap-view",
          opts = {
            winbar = {
              sections = { "watches", "exceptions", "breakpoints", "repl" },
              default_section = "watches",
            },
            windows = {
              height = 12,
              terminal = {
                position = "left",
                hide = {},
              },
            },
          },
        },
      },
      keys = {
        { "<leader>db", "<cmd>DapToggleBreakpoint<cr>", desc = "Toggle Breakpoint" },
        { "<leader>dc", "<cmd>DapContinue<cr>", desc = "Continue" },
        { "<leader>dd", "<cmd>DapViewToggle<cr>", desc = "Toggle DAP View" },
        { "<leader>dw", "<cmd>DapViewWatch<cr>", desc = "Add Watch Expression" },
        { "<leader>di", "<cmd>DapStepInto<cr>", desc = "Step Into" },
        { "<leader>do", "<cmd>DapStepOver<cr>", desc = "Step Over" },
        { "<leader>dO", "<cmd>DapStepOut<cr>", desc = "Step Out" },
        { "<leader>dt", "<cmd>DapTerminate<cr>", desc = "Terminate" },
        {
          "<leader>B",
          function()
            require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
          end,
          desc = "Conditional Breakpoint",
        },
        {
          "<leader>ds",
          function()
            local widgets = require("dap.ui.widgets")
            widgets.centered_float(widgets.scopes, { border = "rounded" })
          end,
          desc = "Inspect Scope",
        },
        {
          "<leader>dK",
          function()
            require("dap.ui.widgets").hover(nil, { border = "rounded" })
          end,
          "DAP Hover",
        },
      },
      config = function()
        local dap = require("dap")
        dap.defaults.fallback.switchbuf = "useopen"

        dap.listeners.before.attach.dapui_config = function()
          require("dap-view").open()
        end
        dap.listeners.before.launch.dapui_config = function()
          require("dap-view").open()
        end

        require("mason-nvim-dap").setup({
          ensure_installed = { "js", "delve" },
          handlers = {
            js = function()
              -- js
              local pwa_node_attach = {
                type = "pwa-node",
                request = "launch",
                name = "js-debug: Attach to Process (pwa-node)",
                processId = require("dap.utils").pick_process,
                cwd = "${workspaceFolder}",
              }
              dap.adapters["pwa-node"] = {
                type = "server",
                port = "${port}",
                executable = { command = vim.fn.exepath("js-debug-adapter"), args = { "${port}" } },
              }
              require("dap.ext.vscode").type_to_filetypes["pwa-node"] = {
                "javascript",
                "javascriptreact",
                "typescript",
                "typescriptreact",
              }
              for _, language in ipairs({ "javascript", "javascriptreact" }) do
                dap.configurations[language] = {
                  {
                    type = "pwa-node",
                    request = "launch",
                    name = "js-debug: Launch (pwa-node)",
                    program = "${file}",
                    cwd = "${workspaceFolder}",
                  },
                  pwa_node_attach,
                }
              end

              -- ts
              local function typescript(args)
                return {
                  type = "pwa-node",
                  request = "launch",
                  name = ("js-debug: Launch (tsx%s)"):format(args and (" " .. table.concat(args, " ")) or ""),
                  program = "${file}",
                  cwd = "${workspaceFolder}",
                  runtimeExecutable = "tsx",
                  runtimeArgs = args,
                  sourceMaps = true,
                  protocol = "inspector",
                  console = "integratedTerminal",
                  resolveSourceMapLocations = {
                    "${workspaceFolder}/dist/**/*.js",
                    "${workspaceFolder}/**",
                    "!**/node_modules/**",
                  },
                }
              end
              for _, language in ipairs({ "typescript", "typescriptreact" }) do
                dap.configurations[language] = {
                  typescript(),
                  typescript({ "--esm" }),
                  pwa_node_attach,
                }
              end
            end,
          },
        })

        vim.api.nvim_create_autocmd({ "FileType" }, {
          pattern = { "dap-view", "dap-view-term", "dap-repl", "dap-float" },
          callback = function(evt)
            vim.keymap.set("n", "q", "<C-w>q", { silent = true, buffer = evt.buf })
          end,
        })
      end,
    },
  },
})

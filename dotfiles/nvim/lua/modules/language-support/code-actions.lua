return lib.module.create({
  name = "language-support/code-action",
  hosts = "*",
  plugins = {
    {
      "luckasRanarison/clear-action.nvim",
      -- event = "LspAttach",
      lazy = false,
      init = function()
        vim.api.nvim_create_autocmd("FileType", {
          pattern = "CodeAction",
          callback = function()
            lib.map.map("n", "q", "<cmd>q<cr>", { buffer = true })
          end,
        })
      end,
      config = function()
        local clear_action = require("clear-action")
        clear_action.setup({
          silent = false,
          signs = {
            enable = true,
            combine = true,
            position = "eol",
            show_count = false,
            show_label = true,
            label_fmt = function(actions)
              local refactor_actions = {}
              for _, action in ipairs(actions) do
                if action.kind ~= nil then
                  if vim.startswith(action.kind, "refactor") then table.insert(refactor_actions, action) end
                end
              end
              if #refactor_actions > 0 then return "⭍" .. #refactor_actions end
              return ""
            end,
            update_on_insert = false,
            icons = {
              combined = "",
            },
            highlights = {
              combined = "NonText",
            },
          },
          popup = {
            enable = true,
            hide_cursor = true,
            highlights = {
              header = "CodeActionHeader",
              label = "CodeActionLabel",
              title = "CodeActionTitle",
            },
          },
          mappings = {
            refactor_inline = { "<leader>ai", "Inline" },
            refactor_extract = { "<leader>ae", "Extract" },
            actions = {
              ["typescript-tools"] = {
                -- waiting to inline function - https://github.com/Microsoft/TypeScript/issues/27070
                ["Inline variable"] = { "<leader>iv", "Inline variable" },
                ["Extract to function in module scope"] = { "<leader>ef", "Extract function" },
                ["Extract to constant"] = { "<leader>ev", "Extract variable" },
              },
            },
          },
        })

        lib.map.map({ "n", "v" }, "<leader>ar", function()
          clear_action.code_action({
            context = { only = { "refactor" } },
            filter = function(action)
              if vim.startswith(action.kind, "refactor") then return true end
              return false
            end,
          })
        end, { desc = "LSP: Refactor" })

        lib.map.map({ "n", "v" }, "<leader>ac", function()
          clear_action.code_action({
            filter = function(action)
              if action.kind and vim.startswith(action.kind, "refactor") then return false end
              return true
            end,
          })
        end, { desc = "LSP: Code action" })
      end,
    },
  },
})

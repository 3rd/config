local close_floating_windows = function()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then vim.api.nvim_win_close(win, true) end
  end
end

return lib.module.create({
  name = "language-support/code-action",
  hosts = "*",
  plugins = {
    {
      "3rd/tiny-code-action.nvim",
      -- "rachartier/tiny-code-action.nvim",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "tiny-code-action.nvim"),
      dependencies = {
        { "nvim-lua/plenary.nvim" },
      },
      event = "LspAttach",
      config = function()
        local global_filter_titles = {
          -- ts
          "Extract function",
          "Extract constant",
          "Convert named imports to namespace import",
          "Convert namespace import to named imports",
          "Convert to optional chain expression",
          "Convert to template string",
          -- eslint
          "Fix all auto-fixable problems",
          "Show documentation for.*",
        }

        local allowed_keys = string.split("acdfimnoprstuxyz0123456789", "")

        local custom_keys = {
          -- ts: general
          { key = "a", pattern = [[^Add braces to arrow function$]] },
          { key = "r", pattern = [[^Remove braces from arrow function$]] },

          -- ts: add import (local/aliases)
          { key = "a", pattern = [[^Add import from "%./.+$]] }, -- "./foo"
          { key = "a", pattern = [[^Add import from "%.%./.+$]] }, -- "../foo"
          { key = "a", pattern = [[^Add import from "@@/.+$]] }, -- "@@/foo"
          { key = "a", pattern = [[^Add import from "@/.+$]] }, -- "@/foo"
          { key = "u", pattern = [[^Update import.+$]] },

          -- eslint
          { key = "d", pattern = [[.+ for this line$]] },
          { key = "a", pattern = [[.+ for the entire file$]] },
          { key = "f", pattern = [[^Fix this.+$]] },

          -- ts: extract function
          { key = "i", pattern = [[^Extract to inner function in arrow function$]] },
          { key = "i", pattern = [[^Extract to inner function in method.+$]] },
          { key = "s", pattern = [[^Extract to function in module scope$]] },
          { key = "m", pattern = [[^Extract to method in class.+$]] },

          -- ts: extract variable
          { key = "c", pattern = [[^Extract to constant in enclosing scope$]] },

          -- ts: extra
          { key = "f", pattern = [[^Infer parameter types from usage$]] },

          -- lua
          { key = "d", pattern = [[^Disable diagnostics on this line.+$]] },
          { key = "a", pattern = [[^Disable diagnostics on this line.+$]] },
          { key = "w", pattern = [[^Disable diagnostics in the workspace.+$]] },

          -- generic
          { key = "a", pattern = [[^Add.+$]] },
          { key = "u", pattern = [[^Update.+$]] },
        }

        local opts = {
          backend = "vim",
          picker = {
            "buffer",
            opts = {
              hotkeys = true,
              auto_preview = false,
              auto_accept = true,
              position = "cursor",
              winborder = "rounded",
              hotkeys_mode = function(titles, used_hotkeys)
                local assigned = {}
                local taken = {}

                -- seed with used hotkeys
                if type(used_hotkeys) == "table" then
                  for k, v in pairs(used_hotkeys) do
                    if type(v) == "string" then
                      taken[v] = true
                    elseif v == true and type(k) == "string" then
                      taken[k] = true
                    end
                  end
                end

                local function try_assign(idx, key)
                  if not assigned[idx] and not taken[key] then
                    assigned[idx] = key
                    taken[key] = true
                    return true
                  end
                  return false
                end

                -- custom keys first
                for _, ck in ipairs(custom_keys) do
                  if not taken[ck.key] then
                    for i, title in ipairs(titles) do
                      if not assigned[i] then
                        local ok, matched = pcall(string.match, title, ck.pattern)
                        if ok and matched then
                          try_assign(i, ck.key)
                          break
                        end
                      end
                    end
                  end
                end

                -- remaining keys
                local ai = 1
                local function next_free_key()
                  while ai <= #allowed_keys do
                    local k = allowed_keys[ai]
                    ai = ai + 1
                    if not taken[k] then return k end
                  end
                  return nil
                end

                for i = 1, #titles do
                  if not assigned[i] then
                    local k = next_free_key()
                    if not k then break end
                    assigned[i] = k
                    taken[k] = true
                  end
                end

                return assigned
              end,
            },
          },
          backend_opts = {
            delta = {
              header_lines_to_remove = 4,
              -- "--config" .. os.getenv("HOME") .. "/.config/delta/config.yml",
              args = {
                "--line-numbers",
              },
            },
          },
          resolve_timeout = 1000,
          signs = {
            quickfix = { "", { link = "DiagnosticWarning" } },
            others = { "", { link = "DiagnosticWarning" } },
            refactor = { "", { link = "DiagnosticInfo" } },
            ["refactor.move"] = { "󰪹", { link = "DiagnosticInfo" } },
            ["refactor.extract"] = { "", { link = "DiagnosticError" } },
            ["source.organizeImports"] = { "", { link = "DiagnosticWarning" } },
            ["source.fixAll"] = { "󰃢", { link = "DiagnosticError" } },
            ["source"] = { "", { link = "DiagnosticError" } },
            ["rename"] = { "󰑕", { link = "DiagnosticWarning" } },
            ["codeAction"] = { "", { link = "DiagnosticWarning" } },
          },
        }

        local plugin = require("tiny-code-action")
        plugin.setup(opts)

        local is_filtered_globally = function(action)
          for _, pattern in ipairs(global_filter_titles) do
            if action.title == pattern then return true end
            local ok, matched = pcall(string.match, action.title, pattern)
            if ok and matched then return true end
          end
          return false
        end

        local sorter = function(items)
          local sorted = vim.tbl_deep_extend("force", {}, items)
          table.sort(sorted, function(a, b)
            local hotkey_a = a.hotkey or "zzz"
            local hotkey_b = b.hotkey or "zzz"
            if #hotkey_a ~= #hotkey_b then return #hotkey_a < #hotkey_b end
            return hotkey_a < hotkey_b
          end)
          return sorted
        end

        lib.map.map({ "n", "v" }, "<leader>ar", function()
          close_floating_windows()
          plugin.code_action({
            filter = function(action)
              if is_filtered_globally(action) then return false end
              if not action.kind then return false end
              if not vim.startswith(action.kind, "refactor") then return false end
              return true
            end,
            sort = sorter,
          })
        end, { desc = "LSP: Refactor" })

        lib.map.map({ "n", "v" }, "<leader>ac", function()
          close_floating_windows()
          plugin.code_action({
            filter = function(action)
              if is_filtered_globally(action) then return false end
              if action.kind and vim.startswith(action.kind, "refactor") then return false end
              return true
            end,
            sort = sorter,
          })
        end, { desc = "LSP: Code action" })

        local extract_function_patterns = {
          "Extract.*function",
          "Extract.*method",
        }
        lib.map.map({ "n", "v" }, "<leader>ef", function()
          close_floating_windows()
          plugin.code_action({
            filter = function(action)
              if is_filtered_globally(action) then return false end
              for _, pattern in ipairs(extract_function_patterns) do
                if action.title == pattern then return true end
                local ok, matched = pcall(string.match, action.title, pattern)
                if ok and matched then return true end
              end
              return false
            end,
            sort = sorter,
          })
        end, { desc = "LSP: Extract function" })

        local extract_variable_patterns = {
          "Extract.*variable",
          "Extract.*constant",
          "Extract.*field",
        }
        lib.map.map({ "n", "v" }, "<leader>ev", function()
          close_floating_windows()
          plugin.code_action({
            filter = function(action)
              if is_filtered_globally(action) then return false end
              for _, pattern in ipairs(extract_variable_patterns) do
                if action.title == pattern then return true end
                local ok, matched = pcall(string.match, action.title, pattern)
                if ok and matched then return true end
              end
              return false
            end,
            sort = sorter,
          })
        end, { desc = "LSP: Extract variable" })

        local function set_tiny_window_conceal(win)
          pcall(vim.api.nvim_set_option_value, "conceallevel", 3, { win = win })
          pcall(vim.api.nvim_set_option_value, "concealcursor", "n", { win = win })
        end

        vim.api.nvim_create_autocmd("User", {
          pattern = "TinyCodeActionWindowEnterMain",
          callback = function(ev)
            local buf = ev.data.buf
            local win = ev.data.win

            pcall(function()
              require("render-markdown.api").buf_disable()
            end)

            vim.schedule(function()
              set_tiny_window_conceal(win)
            end)

            local aug = vim.api.nvim_create_augroup("tiny_code_action_window_" .. tostring(buf), { clear = true })
            vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
              group = aug,
              callback = function()
                set_tiny_window_conceal(win)
              end,
            })
          end,
        })
      end,
    },
  },
})

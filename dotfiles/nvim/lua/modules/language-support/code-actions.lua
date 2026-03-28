local config = {
  async = false,
  code_action_request_timeout_ms = 2000,
}

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

        local get_line_diagnostics = function(bufnr)
          local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1

          if vim.fn.has("nvim-0.11") == 1 then
            local diagnostics = vim.diagnostic.get(bufnr, { lnum = current_line })
            local for_lsp_diagnostics = {}

            table.sort(diagnostics, function(a, b)
              return math.abs(a.lnum - current_line) < math.abs(b.lnum - current_line)
            end)

            for _, diagnostic in ipairs(diagnostics) do
              if diagnostic.user_data and diagnostic.user_data.lsp then
                table.insert(for_lsp_diagnostics, diagnostic.user_data.lsp)
              end
            end

            return for_lsp_diagnostics
          end

          return vim.lsp.diagnostic.get_line_diagnostics(bufnr)[current_line] or {}
        end

        local build_code_action_params = function(request_opts)
          local position_encoding = vim.api.nvim_get_option_value("encoding", { scope = "local" })
          local params

          if request_opts.range then
            params = {
              textDocument = { uri = vim.uri_from_bufnr(request_opts.bufnr) },
              range = {
                start = { line = request_opts.range.start[1] - 1, character = request_opts.range.start[2] },
                ["end"] = { line = request_opts.range["end"][1] - 1, character = request_opts.range["end"][2] },
              },
            }
          elseif vim.fn.mode() == "n" then
            params = {
              textDocument = { uri = vim.uri_from_bufnr(request_opts.bufnr) },
              range = vim.lsp.util.make_range_params(0, position_encoding).range,
            }
          else
            params = {
              textDocument = { uri = vim.uri_from_bufnr(request_opts.bufnr) },
              range = vim.lsp.util.make_given_range_params(
                { vim.fn.getpos("'<")[2], vim.fn.getpos("'<")[3] },
                { vim.fn.getpos("'>")[2], vim.fn.getpos("'>")[3] },
                0,
                position_encoding
              ).range,
            }
          end

          local context = {}
          if request_opts.context and request_opts.context.triggerKind then
            context.triggerKind = request_opts.context.triggerKind
          else
            context.triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked
          end

          if request_opts.context and request_opts.context.diagnostics then
            context.diagnostics = request_opts.context.diagnostics
          else
            context.diagnostics = get_line_diagnostics(request_opts.bufnr)
          end

          if request_opts.context and request_opts.context.only then context.only = request_opts.context.only end

          params.context = context

          return params, context
        end

        local configure_code_action_finder = function()
          local finder = require("tiny-code-action.finder")

          if finder._original_code_action_finder == nil then
            finder._original_code_action_finder = finder.code_action_finder
          end

          if config.async ~= false then
            finder.code_action_finder = finder._original_code_action_finder
            return
          end

          finder.code_action_finder = function(request_opts, callback)
            local clients = vim.lsp.get_clients({ bufnr = request_opts.bufnr, method = "textDocument/codeAction" })
            if not clients or #clients == 0 then return nil end

            local params, context = build_code_action_params(request_opts)
            local ok, responses, err = pcall(
              vim.lsp.buf_request_sync,
              request_opts.bufnr,
              "textDocument/codeAction",
              params,
              config.code_action_request_timeout_ms
            )

            if not ok then
              vim.notify("Failed to fetch code actions: " .. tostring(responses), vim.log.levels.ERROR)
              return nil
            end

            if err then vim.notify("Code action request timed out: " .. tostring(err), vim.log.levels.WARN) end

            local results = {}

            for client_id, response in pairs(responses or {}) do
              if response and response.result then
                local client = vim.lsp.get_client_by_id(client_id)
                if client then
                  for _, action in ipairs(response.result) do
                    table.insert(results, {
                      client = client,
                      action = action,
                      context = context,
                    })
                  end
                end
              end
            end

            if vim.tbl_isempty(results) then
              vim.notify("No code actions found.", vim.log.levels.INFO)
              return nil
            end

            callback(results)
          end
        end

        local plugin = require("tiny-code-action")
        plugin.setup(opts)
        configure_code_action_finder()

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

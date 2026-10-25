-- ts-error-translator only translates pushed diagnostics, and tsc delivers them by pull only. This wraps the pull
-- handler at startup because tsc answers before the lazily loaded plugin would be set up.
local translate_pull_diagnostics = function()
  local on_pull_diagnostics = vim.lsp.handlers["textDocument/diagnostic"]

  vim.lsp.handlers["textDocument/diagnostic"] = function(err, result, ctx, ...)
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if not (result and result.items and client) then return on_pull_diagnostics(err, result, ctx, ...) end

    local has_translator, translator = pcall(require, "ts-error-translator")
    if has_translator and vim.tbl_contains(translator.config.servers, client.name) then
      for _, item in ipairs(result.items) do
        local prefix = item.code and ("TS%s: "):format(item.code) or ""
        local parsed = translator.parse_errors(prefix .. item.message)
        if parsed[1] and parsed[1].improvedError then item.message = parsed[1].improvedError.body end
      end
    end

    return on_pull_diagnostics(err, result, ctx, ...)
  end
end

return lib.module.create({
  name = "language-support/lsp",
  hosts = "*",
  setup = function()
    vim.api.nvim_create_user_command("LspLog", function()
      vim.cmd("tabnew " .. vim.lsp.log.get_filename())
    end, { desc = "Open LSP log file in a new tab" })
    translate_pull_diagnostics()
  end,
  plugins = {
    {
      "neovim/nvim-lspconfig",
      lazy = false,
      config = function()
        local servers = require("config/lsp-servers")
        local lsp_info = require("modules/language-support/lsp-info")

        for _, server in ipairs(servers) do
          local config = vim.lsp.config[server]
          config.flags = vim.tbl_deep_extend("force", config.flags or {}, {
            allow_incremental_sync = true,
          })
          if config.enabled ~= false then vim.lsp.enable(server) end
        end

        lsp_info.register_user_command()
        vim.api.nvim_exec_autocmds("FileType", {})
      end,
    },
    {
      "b0o/schemastore.nvim",
    },
    {
      "dmmulroy/ts-error-translator.nvim",
      event = "VeryLazy",
      opts = {
        auto_attach = true,
        servers = {
          "astro",
          "svelte",
          "tsc",
          "tsgo",
          "ts_ls",
          "tsserver",
          "typescript-tools",
          "volar",
          "vtsls",
        },
      },
      -- config = function()
      --   vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx)
      --     if ctx.client_id == "vtsls" then require("ts-error-translator").translate_diagnostics(err, result, ctx) end
      --     vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
      --   end
      -- end,
    },
    {
      "j-hui/fidget.nvim",
      -- tag = "legacy",
      event = "VeryLazy",
      opts = {
        notification = {
          window = { winblend = 0 },
        },
        progress = {
          ignore_done_already = true,
        },
      },
    },
    {
      "esmuellert/nvim-eslint",
      event = { "BufReadPre", "BufNewFile" },
      dependencies = {
        "neovim/nvim-lspconfig",
      },
      opts = function(_, opts)
        -- override
        local eslintConfigOverride = nil
        local eslintResolveRelativeTo = nil
        local root = lib.path.find_root({ "package.json" })
        -- if root and not lib.fs.file.exists(lib.path.resolve(root, "eslint.config.js")) then
        if root and not lib.fs.file.exists(lib.path.resolve(root, ".noglobaleslint")) then
          eslintConfigOverride = lib.path.resolve_config("linters/eslint/dist/main.js")
          eslintResolveRelativeTo = lib.path.resolve_config("linters/eslint/node_modules")
        end

        opts = vim.tbl_deep_extend("force", opts or {}, {
          -- debug = true,
          root_dir = function(bufnr)
            return vim.fs.root(bufnr, { ".root", "package.json", ".git" }) or vim.uv.cwd()
          end,
          handlers = {
            ["eslint/noConfig"] = function(_, result)
              vim.notify(result.message, vim.log.levels.WARN)
              return {}
            end,
            ["workspace/diagnostic/refresh"] = function(_, _, ctx)
              local bufnr = vim.api.nvim_get_current_buf()
              local client = vim.lsp.get_client_by_id(ctx.client_id)
              if client and client.namespace then vim.diagnostic.reset(client.namespace, bufnr) end
              return true
            end,
          },
          settings = {
            format = true,
            -- useESLintClass = false,
            run = "onType",
            options = vim.tbl_deep_extend("force", {
              cache = true,
              cacheLocation = ".eslintcache",
              fix = false,
              overrideConfigFile = eslintConfigOverride,
              resolvePluginsRelativeTo = eslintResolveRelativeTo,
            }, eslintConfigOverride and { useEslintrc = false } or {}),
            nodePath = eslintResolveRelativeTo,
            workingDirectories = { mode = "auto" },
            workingDirectory = function(bufnr)
              return { directory = vim.fs.root(bufnr, { "package.json" }) }
            end,
          },
        })

        if eslintConfigOverride then
          opts.settings.useFlatConfig = false
          opts.settings.experimental = { useFlatConfig = false }
        end

        return opts
      end,
    },
  },
})

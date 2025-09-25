return lib.module.create({
  name = "language-support/lsp",
  hosts = "*",
  plugins = {
    {
      "neovim/nvim-lspconfig",
      lazy = false,
      config = function()
        local servers = {
          "ast_grep",
          "bashls",
          "clangd",
          "csharp_ls",
          "cssls",
          "cssmodules_ls",
          "dockerls",
          "gopls",
          "html",
          "jsonls",
          "lua_ls",
          "nills",
          "rust_analyzer",
          "tailwindcss",
          "eslint",
          "ts_ls",
          -- "vtsls",
          "yamlls",
          "zls",
        }

        for _, server in ipairs(servers) do
          local config = vim.lsp.config[server]
          config.flags = vim.tbl_deep_extend("force", config.flags or {}, {
            allow_incremental_sync = true,
          })
          if config.enabled ~= false then vim.lsp.enable(server) end
        end

        vim.api.nvim_exec_autocmds("FileType", {})
      end,
    },
    {
      "b0o/schemastore.nvim",
      lazy = false,
    },
    {
      "dmmulroy/ts-error-translator.nvim",
      event = "VeryLazy",
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
      enabled = lib.path.find_root({ "package.json" }) ~= nil,
      lazy = false,
      dependencies = {
        "neovim/nvim-lspconfig",
      },
      opts = function(_, opts)
        local root_pattern = require("lspconfig.util").root_pattern
        -- local function root_pattern(...)
        --   local patterns = { ... }
        --   return function(startpath)
        --     return vim.fs.root(startpath or vim.api.nvim_buf_get_name(0), patterns)
        --   end
        -- end

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
          root_dir = root_pattern(".root", "package.json", ".git") or vim.uv.cwd(),
          handlers = {
            ["eslint/noConfig"] = function(_, result)
              vim.notify(result.message, vim.log.levels.WARN)
              return {}
            end,
            ["workspace/diagnostic/refresh"] = function(_, _, ctx)
              local ns = vim.lsp.diagnostic.get_namespace(ctx.client_id)
              local bufnr = vim.api.nvim_get_current_buf()
              vim.diagnostic.reset(ns, bufnr)
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

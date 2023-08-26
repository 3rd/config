local config = {
  -- client.server_capabilities.documentFormattingProvider
  formatting = {
    enable = { "eslint" },
    disable = { "html" },
  },
}

local setup = function()
  -- lsp border
  local border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
  local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
    opts = opts or {}
    opts.border = opts.border or border
    opts.max_width = 80
    return orig_util_open_floating_preview(contents, syntax, opts, ...)
  end
end

local ensure_installed = {
  -- lsp
  "astro",
  "bashls",
  "clangd",
  "cssls",
  "cssmodules_ls",
  "dockerls",
  "eslint",
  "golangci_lint_ls",
  "gopls",
  "html",
  "jsonls",
  "prismals",
  "rust_analyzer",
  "tailwindcss",
  "vimls",
  "vuels",
  "typescript-language-server",
  "nil_ls",
  "vtsls",
  "yamlls",
  -- formatters
  "prettierd",
  "rustywind",
  "fixjson",
}

local setup_lspconfig = function()
  require("mason-tool-installer").setup({
    ensure_installed = ensure_installed,
    auto_update = false,
    run_on_start = true,
    start_delay = 1000,
    debounce_hours = 5,
  })

  local lsp_config = {
    mason = {
      ui = { border = "rounded" },
    },
    mason_lspconfig = {
      ui = {
        icons = {
          server_installed = "✓",
          server_pending = "➜",
          server_uninstalled = "✗",
        },
      },
    },
    mason_dap = {
      ensure_installed = {
        "chrome", -- chrome-debug-adapter
        "delve",
        "js", -- js-debug-adapter
        "node2", -- node-debug2-adapter
      },
    },
    lspconfig = {
      nixd = {},
      -- nil_ls = {},
      zls = {},
      bashls = {},
      cssls = {
        settings = {
          css = { lint = { unknownAtRules = "ignore" } },
          scss = { lint = { unknownAtRules = "ignore" } },
        },
      },
      dockerls = {},
      gopls = {
        cmd = { "gopls", "-remote=auto", "-remote.debug=:0" },
        settings = {
          gopls = {
            analyses = {
              unusedparams = true,
              unreachable = false,
            },
            codelenses = {
              generate = true,
              gc_details = true,
              test = true,
              tidy = true,
            },
            usePlaceholders = true,
            completeUnimported = true,
            staticcheck = true,
            matcher = "fuzzy",
            diagnosticsDelay = "500ms",
            symbolMatcher = "fuzzy",
            gofumpt = false,
            buildFlags = { "-tags", "integration" },
          },
        },
      },
      html = {},
      vimls = {},
      astro = {},
      clangd = {
        filetypes = { "cc", "c", "cpp", "objc", "objcpp", "cuda", "proto" },
      },
      rust_analyzer = {
        settings = {
          ["rust-analyzer"] = {
            assist = { importGranularity = "module", importPrefix = "by_self" },
            cargo = { loadOutDirsFromCheck = true },
            procMacro = { enable = true },
          },
        },
      },
      lua_ls = {
        -- cmd = {
        --   vim.fn.exepath("lua-language-server"),
        --   "--loglevel=trace",
        --   "--logpath=/tmp/luals.log",
        -- },
        settings = {
          Lua = {
            completion = { callSnippet = "Replace" },
            diagnostics = { enable = true, globals = { "vim", "log", "throw" } },
            format = { enable = false },
            runtime = { version = "LuaJIT" },
            workspace = {
              ignoreDir = { "plugins", "sandbox" },
              checkThirdParty = false,
              useGitIgnore = true,
              ignoreSubmodules = true,
              library = { vim.env.VIMRUNTIME },
              -- library = {
              -- [vim.fn.expand("$VIMRUNTIME/lua")] = true,
              -- [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
              -- [vim.fn.stdpath("data") .. "/lazy/lazy.nvim/lua/lazy"] = true,
              -- },
            },
            telemetry = { enable = false },
          },
        },
        handlers = {
          -- always go to the first definition
          ["textDocument/definition"] = function(err, result, ...)
            if vim.tbl_islist(result) or type(result) == "table" then result = result[1] end
            vim.lsp.handlers["textDocument/definition"](err, result, ...)
          end,
        },
      },
      -- tsserver = {
      --   init_options = {
      --     hostInfo = "neovim",
      --     disableAutomaticTypingAcquisition = true,
      --     preferences = {
      --       allowIncompleteCompletions = false,
      --       includeCompletionsForModuleExports = false,
      --       importModuleSpecifierPreference = "shortest",
      --       includePackageJsonAutoImports = "off",
      --     },
      --     maxTsServerMemory = 2 * 4096,
      --   },
      --   settings = {
      --     format = { enable = false },
      --   },
      --   handlers = {
      --     -- always go to the first definition
      --     ["textDocument/definition"] = function(err, result, ...)
      --       if vim.tbl_islist(result) or type(result) == "table" then result = result[1] end
      --       vim.lsp.handlers["textDocument/definition"](err, result, ...)
      --     end,
      --   },
      -- },
      vtsls = {
        -- https://github.com/yioneko/vtsls/blob/main/packages/service/configuration.schema.json
        settings = {
          javascript = {
            format = { enable = false },
            preferences = {
              useAliasesForRenames = true,
            },
          },
          typescript = {
            format = { enable = false },
            tsserver = {
              maxTsServerMemory = 4000,
              -- experimental = { enableProjectDiagnostics = true }, -- this breaks vts by opening unrelated files, funny
            },
            preferences = {
              includePackageJsonAutoImports = "off",
              useAliasesForRenames = true,
            },
          },
          vtsls = {
            experimental = {
              completion = {
                enableServerSideFuzzyMatch = true,
                entriesLimit = 150,
              },
            },
          },
        },
        handlers = {
          -- always go to the first definition
          ["textDocument/definition"] = function(err, result, ...)
            if vim.tbl_islist(result) or type(result) == "table" then result = result[1] end
            vim.lsp.handlers["textDocument/definition"](err, result, ...)
          end,
        },
      },
      vuels = {
        init_options = {
          config = {
            vetur = {
              completion = {
                autoImport = true,
                tagCasing = "kebab",
                useScaffoldSnippets = false,
              },
              format = { defaultFormatter = { js = "none", ts = "none" } },
              useWorkspaceDependencies = false,
              validation = { script = true, style = true, template = true },
            },
          },
        },
      },
      eslint = {
        filetypes = {
          "javascript",
          "javascriptreact",
          "javascript.jsx",
          "typescript",
          "typescriptreact",
          "typescript.tsx",
          "vue",
          "svelte",
          "graphql",
        },
        settings = {
          codeAction = {
            disableRuleComment = { enable = true, location = "separateLine" },
            showDocumentation = { enable = true },
          },
          -- experimental = { useFlatConfig = true },
          nodePath = lib.path.resolve_config("linters/eslint/node_modules"),
          onIgnoredFiles = "off",
          options = {
            cache = true,
            fix = true,
            overrideConfigFile = lib.path.resolve_config("linters/eslint/dist/main.js"),
            resolvePluginsRelativeTo = lib.path.resolve_config("linters/eslint/node_modules"),
            useEslintrc = false,
          },
          packageManager = "npm",
          run = "onSave",
          workingDirectory = { mode = "auto" },
        },
      },
      prismals = {},
      jsonls = {
        init_options = {
          provideFormatter = false,
        },
        settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      },
      yamlls = {
        settings = {
          yaml = {
            schemas = require("schemastore").yaml.schemas(),
          },
        },
      },
      cssmodules_ls = {},
      tailwindcss = {},
    },
  }

  require("mason").setup(lsp_config.mason)
  require("mason-lspconfig").setup(lsp_config.mason_lspconfig)
  require("mason-nvim-dap").setup(lsp_config.mason_dap)

  -- tweaks
  require("lspconfig.ui.windows").default_options.border = "rounded"

  -- load modules
  local modules = lib.module.get_enabled_modules()
  local modules_with_capabilities = table.filter(modules, function(module)
    return ((module.hooks or {}).lsp or {}).capabilities ~= nil
  end)
  local modules_with_on_attach = table.filter(modules, function(module)
    return ((module.hooks or {}).lsp or {}).on_attach ~= nil
  end)
  local modules_with_on_attach_call = table.filter(modules, function(module)
    return ((module.hooks or {}).lsp or {}).on_attach_call ~= nil
  end)

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  for _, module in ipairs(modules_with_capabilities) do
    capabilities = module.hooks.lsp.capabilities(capabilities)
  end
  capabilities = vim.tbl_deep_extend(
    "force",
    capabilities,
    { workspace = { didChangeWatchedFiles = { dynamicRegistration = true } } }
  )

  local on_attach = function(client, bufnr)
    -- mappings
    for _, mapping in ipairs(require("config/mappings").lsp) do
      local mode, lhs, rhs, opts_or_desc = mapping[1], mapping[2], mapping[3], mapping[4]
      local opts = lib.is.string(opts_or_desc) and { desc = opts_or_desc } or opts_or_desc or {}
      opts.buffer = bufnr
      lib.map.map(mode, lhs, rhs, opts)
    end

    -- lsp formatting
    if vim.tbl_contains(config.formatting.enable, client.name) then
      client.server_capabilities.documentFormattingProvider = true
    elseif vim.tbl_contains(config.formatting.disable, client.name) then
      client.server_capabilities.documentFormattingProvider = false
    end

    -- on_attach call hooks
    for _, module in ipairs(modules_with_on_attach_call) do
      module.hooks.lsp.on_attach_call(client, bufnr)
    end
  end

  -- setup servers
  local root_pattern = require("lspconfig.util").root_pattern
  local default_root_dir = root_pattern(".root", ".git", "go.mod", "package.json") or vim.loop.cwd()
  for server_name, server_options in pairs(lsp_config.lspconfig) do
    local opts = vim.tbl_deep_extend("force", server_options, {
      capabilities = capabilities,
      on_attach = on_attach,
    })
    opts.flags = opts.flags or {}
    opts.flags.allow_incremental_sync = true
    if not opts.root_dir then opts.root_dir = default_root_dir end
    require("lspconfig")[server_name].setup(opts)
  end

  -- on_attach hooks
  for _, module in ipairs(modules_with_on_attach) do
    module.hooks.lsp.on_attach(on_attach)
  end

  vim.api.nvim_exec_autocmds("FileType", {})
end

return lib.module.create({
  name = "language-support/lsp",
  setup = setup,
  plugins = {
    {
      "neovim/nvim-lspconfig",
      event = "VeryLazy",
      dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "jay-babu/mason-nvim-dap.nvim",
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        "ibhagwan/fzf-lua",
        "b0o/schemastore.nvim",
      },
      config = setup_lspconfig,
    },
    {
      "j-hui/fidget.nvim",
      tag = "legacy",
      event = "VeryLazy",
      config = function()
        require("fidget").setup({
          window = { blend = 0 },
          sources = {
            ["null-ls"] = { ignore = true },
          },
        })
      end,
    },
  },
})

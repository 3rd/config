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

  -- vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
  --   border = "rounded",
  -- })

  -- ty https://github.com/MariaSolOs/dotfiles/blob/fedora/.config/nvim/lua/lsp.lua#L278
  local methods = vim.lsp.protocol.Methods
  local inlay_hint_handler = vim.lsp.handlers[methods.textDocument_inlayHint]
  local inlay_hint_max_len = 40
  vim.lsp.handlers[methods.textDocument_inlayHint] = function(err, result, ctx, config)
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if client and client.name == "typescript-tools" then
      result = vim.iter.map(function(hint)
        local label = hint.label ---@type string
        if label:len() >= inlay_hint_max_len then label = label:sub(1, inlay_hint_max_len - 1) .. "…" end
        hint.label = label
        return hint
      end, result)
    end
    inlay_hint_handler(err, result, ctx, config)
  end
end

local setup_lspconfig = function()
  local root_pattern = require("lspconfig.util").root_pattern

  local overrides = {
    -- client.server_capabilities.documentFormattingProvider
    formatting = {
      enable = { "eslint" },
      disable = { "html" },
    },
  }

  local servers = {
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
      root_dir = root_pattern(".root", "init.lua", ".git"),
      settings = {
        Lua = {
          completion = { callSnippet = "Replace" },
          -- runtime = { version = "LuaJIT" },
          -- diagnostics = { globals = { "vim", "log", "throw" } },
          workspace = {
            -- checkThirdParty = false,
            -- library = {
            --   [vim.fn.expand("$VIMRUNTIME/lua")] = true,
            --   [vim.fn.stdpath("config") .. "/lua"] = true,
            -- },
            ignoreDir = { ".git", "node_modules", "linters" },
          },
          -- telemetry = { enable = false },
          -- hint = { enable = true },
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
    -- vtsls = {
    --   -- https://github.com/yioneko/vtsls/blob/main/packages/service/configuration.schema.json
    --   settings = {
    --     javascript = {
    --       format = { enable = false },
    --       preferences = {
    --         useAliasesForRenames = true,
    --       },
    --       inlayHints = {
    --         parameterNames = { enabled = "literals" },
    --         parameterTypes = { enabled = true },
    --         variableTypes = { enabled = true },
    --         propertyDeclarationTypes = { enabled = true },
    --         functionLikeReturnTypes = { enabled = true },
    --         enumMemberValues = { enabled = true },
    --       },
    --       updateImportsOnFileMove = {
    --         enabled = "always",
    --       },
    --     },
    --     typescript = {
    --       format = { enable = false },
    --       tsserver = {
    --         maxTsServerMemory = 4000,
    --         -- experimental = { enableProjectDiagnostics = true }, -- this breaks vts by opening unrelated files, funny
    --       },
    --       preferences = {
    --         includePackageJsonAutoImports = "off",
    --         useAliasesForRenames = true,
    --       },
    --       inlayHints = {
    --         parameterNames = { enabled = "literals" },
    --         parameterTypes = { enabled = true },
    --         variableTypes = { enabled = true },
    --         propertyDeclarationTypes = { enabled = true },
    --         functionLikeReturnTypes = { enabled = true },
    --         enumMemberValues = { enabled = true },
    --       },
    --       updateImportsOnFileMove = {
    --         enabled = "always",
    --       },
    --     },
    --     vtsls = {
    --       experimental = {
    --         completion = {
    --           enableServerSideFuzzyMatch = true,
    --           entriesLimit = 150,
    --         },
    --       },
    --     },
    --   },
    --   handlers = {
    --     -- always go to the first definition
    --     ["textDocument/definition"] = function(err, result, ...)
    --       if vim.tbl_islist(result) or type(result) == "table" then result = result[1] end
    --       vim.lsp.handlers["textDocument/definition"](err, result, ...)
    --     end,
    --     ["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
    --       require("ts-error-translator").translate_diagnostics(err, result, ctx, config)
    --       vim.lsp.handlers["textDocument/publishDiagnostics"](err, result, ctx, config)
    --     end,
    --   },
    -- },
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
    quick_lint_js = {
      cmd = { "quick-lint-js", "--lsp-server" },
      filetypes = {
        "javascript",
        "javascriptreact",
        "javascript.jsx",
        "typescript",
        "typescriptreact",
        "typescript.tsx",
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
  }

  if lib.fs.file.exists("sgconfig.yml") then
    local configs = require("lspconfig.configs")
    configs.ast_grep = {
      default_config = {
        cmd = { "ast-grep", "lsp" },
        single_file_support = false,
        root_dir = root_pattern("sgconfig.yml"),
      },
    }
    servers.ast_grep = {}
  end

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

  -- hook.lsp.capabilities
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  for _, module in ipairs(modules_with_capabilities) do
    capabilities = module.hooks.lsp.capabilities(capabilities)
  end
  capabilities = vim.tbl_deep_extend("force", capabilities, {
    workspace = {
      -- https://github.com/neovim/neovim/issues/23291
      -- didChangeWatchedFiles = { dynamicRegistration = false },
    },
  })

  -- build on_attach()
  local on_attach = function(client, bufnr)
    -- mappings
    for _, mapping in ipairs(require("config/mappings").lsp) do
      local mode, lhs, rhs, opts_or_desc = mapping[1], mapping[2], mapping[3], mapping[4]
      local opts = lib.is.string(opts_or_desc) and { desc = opts_or_desc } or opts_or_desc or {}
      opts.buffer = bufnr
      lib.map.map(mode, lhs, rhs, opts)
    end

    -- lsp formatting
    if vim.tbl_contains(overrides.formatting.enable, client.name) then
      client.server_capabilities.documentFormattingProvider = true
    elseif vim.tbl_contains(overrides.formatting.disable, client.name) then
      client.server_capabilities.documentFormattingProvider = false
    end

    -- hook.lsp.on_attach_call
    for _, module in ipairs(modules_with_on_attach_call) do
      module.hooks.lsp.on_attach_call(client, bufnr)
    end
  end

  -- hook.lsp.on_attach
  for _, module in ipairs(modules_with_on_attach) do
    on_attach = module.hooks.lsp.on_attach(on_attach)
  end

  -- setup servers
  local default_root_dir = root_pattern(".root", ".git", "go.mod", "package.json") or vim.loop.cwd()
  for server_name, server_options in pairs(servers) do
    local opts = vim.tbl_deep_extend("force", server_options, {
      capabilities = capabilities,
      on_attach = on_attach,
    })
    opts.flags = opts.flags or {}
    opts.flags.allow_incremental_sync = true
    if not opts.root_dir then opts.root_dir = default_root_dir end
    require("lspconfig")[server_name].setup(opts)
  end

  vim.api.nvim_exec_autocmds("FileType", {})
end

return lib.module.create({
  name = "language-support/lsp",
  setup = setup,
  plugins = {
    {
      "neovim/nvim-lspconfig",
      event = { "BufReadPre", "BufNewFile" },
      dependencies = {
        "b0o/schemastore.nvim",
        "dmmulroy/ts-error-translator.nvim",
        { "antosha417/nvim-lsp-file-operations", opts = {} },
        {
          "folke/neodev.nvim",
          opts = {
            library = {
              enabled = true,
              runtime = true,
              types = true,
              plugins = { "nvim-treesitter" },
            },
            setup_jsonls = true,
            lspconfig = true,
            pathStrict = true,
          },
        },
      },
      config = setup_lspconfig,
    },
    {
      "j-hui/fidget.nvim",
      tag = "legacy",
      event = "VeryLazy",
      opts = {
        window = { blend = 0 },
      },
    },
  },
})

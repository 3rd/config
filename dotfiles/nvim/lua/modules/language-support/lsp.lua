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

  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
    update_in_insert = false,
  })

  -- vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
  --   border = "rounded",
  -- })

  -- ty https://github.com/MariaSolOs/dotfiles/blob/fedora/.config/nvim/lua/lsp.lua#L278
  -- local methods = vim.lsp.protocol.Methods
  -- local inlay_hint_handler = vim.lsp.handlers[methods.textDocument_inlayHint]
  -- local inlay_hint_max_len = 40
  -- vim.lsp.handlers[methods.textDocument_inlayHint] = function(err, result, ctx, config)
  --   local client = vim.lsp.get_client_by_id(ctx.client_id)
  --   if client and client.name == "typescript-tools" then
  --     result = vim.iter(result):map(function(hint)
  --       local label = hint.label ---@type string
  --       if label:len() >= inlay_hint_max_len then label = label:sub(1, inlay_hint_max_len - 1) .. "…" end
  --       hint.label = label
  --       return hint
  --     end)
  --   end
  --   inlay_hint_handler(err, result, ctx, config)
  -- end

  vim.keymap.del("n", "grn")
  vim.keymap.del("n", "gra")
  vim.keymap.del("n", "grr")
  vim.keymap.del("n", "gri")
  vim.keymap.del("n", "gO")
end

local setup_lspconfig = function()
  local root_pattern = require("lspconfig.util").root_pattern

  local load_luarc = function()
    local root = root_pattern(".luarc.json")(lib.path.cwd())
    if not root then return {} end
    local luarc_path = lib.path.resolve(root, ".luarc.json")
    if not lib.fs.file.is_readable(luarc_path) then return {} end
    local luarc = lib.fs.file.read(luarc_path)
    return vim.fn.json_decode(luarc)
  end

  -- eslint
  local eslintConfigOverride = nil
  local eslintResolveRelativeTo = nil
  local root = lib.path.find_root()
  -- if root and not lib.fs.file.exists(lib.path.resolve(root, "eslint.config.js")) then
  eslintConfigOverride = lib.path.resolve_config("linters/eslint/dist/main.js")
  eslintResolveRelativeTo = lib.path.resolve_config("linters/eslint/node_modules")
  -- end

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
    csharp_ls = {
      init_options = {
        AutomaticWorkspaceInit = true,
      },
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
        Lua = vim.tbl_deep_extend("keep", load_luarc(), {
          completion = { callSnippet = "Replace" },
          runtime = {
            version = "LuaJIT",
            path = vim.split(package.path, ";"),
            pathStrict = true,
          },
          diagnostics = {
            unusedLocalExclude = { "_*" },
            globals = { "vim", "describe", "it", "before_each", "after_each" },
            disable = { "missing-fields", "unused-local" },
          },
          workspace = {
            library = {
              [".luarc.json"] = true,
              [vim.fn.expand("$VIMRUNTIME/lua")] = true,
              [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
              [vim.fn.stdpath("config") .. "/lua"] = true,
              [vim.fn.expand("$PWD/lua")] = true,
            },
            ignoreDir = { ".git", "node_modules", "linters" },
            checkThirdParty = "Ask",
          },
          hint = { enable = true },
          semantic = { keyword = true },
          telemetry = { enable = false },
        }),
      },
      handlers = {
        -- always go to the first definition
        ["textDocument/definition"] = function(err, result, ...)
          if vim.islist(result) or type(result) == "table" then result = result[1] end
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
    --   flags = {
    --     allow_incremental_sync = false,
    --     debounce_text_changes = 5000,
    --   },
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
    --         maxTsServerMemory = "auto",
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
    --       if vim.islist(result) or type(result) == "table" then result = result[1] end
    --       vim.lsp.handlers["textDocument/definition"](err, result, ...)
    --     end,
    --     ["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
    --       if ctx.client_id == "vtsls" then
    --         require("ts-error-translator").translate_diagnostics(err, result, ctx, config)
    --       end
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
    -- eslint = {
    --   cmd = { "vscode-eslint-language-server", "--stdio" },
    --   filetypes = {
    --     "javascript",
    --     "javascriptreact",
    --     "javascript.jsx",
    --     "typescript",
    --     "typescriptreact",
    --     "typescript.tsx",
    --     "vue",
    --     "svelte",
    --     "graphql",
    --   },
    --   flags = {
    --     allow_incremental_sync = true,
    --     -- debounce_text_changes = 1000,
    --   },
    --   settings = {
    --     useESLintClass = true,
    --     codeActionOnSave = {
    --       enable = false,
    --       mode = "all",
    --     },
    --     quiet = false,
    --     onIgnoredFiles = "off",
    --     rulesCustomizations = {},
    --     run = "onSave",
    --     codeAction = {
    --       disableRuleComment = { enable = true, location = "separateLine" },
    --       showDocumentation = { enable = true },
    --     },
    --     packageManager = "pnpm",
    --     options = vim.tbl_deep_extend("force", {
    --       cache = true,
    --       fix = true,
    --       overrideConfigFile = eslintConfigOverride,
    --       resolvePluginsRelativeTo = eslintResolveRelativeTo,
    --     }, eslintConfigOverride and { useEslintrc = false } or {}),
    --     nodePath = eslintResolveRelativeTo,
    --   },
    -- },
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
      didChangeWatchedFiles = { dynamicRegistration = false },
    },
    textDocument = { completion = { completionItem = { snippetSupport = true } } },
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
  local default_root_dir = root_pattern(".root", ".git", "go.mod", "package.json") or vim.uv.cwd()
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
  hosts = "*",
  setup = setup,
  plugins = {
    {
      "neovim/nvim-lspconfig",
      event = "VeryLazy",
      dependencies = {
        "b0o/schemastore.nvim",
        "dmmulroy/ts-error-translator.nvim",
      },
      config = setup_lspconfig,
    },

    -- {
    --   "folke/neodev.nvim",
    --   ft = "lua",
    --   dependencies = { "neovim/nvim-lspconfig" },
    --   opts = {
    --     library = {
    --       enabled = true,
    --       runtime = true,
    --       types = true,
    --       plugins = {
    --         "nvim-treesitter",
    --         "testing.nvim",
    --         "sqlite.nvim",
    --       },
    --     },
    --     setup_jsonls = true,
    --     lspconfig = true,
    --     pathStrict = true,
    --   },
    -- },
    {
      "folke/lazydev.nvim",
      ft = "lua", -- only load on lua files
      dependencies = {
        { "Bilal2453/luvit-meta", lazy = true }, -- optional `vim.uv` typings
      },
      opts = {
        library = {
          "lazy.nvim",
          { path = "luvit-meta/library", words = { "vim%.uv" } },
          { path = "image.nvim", words = { "image" } },
          { path = "sqlite.nvim", words = { "sqlite" } },
          { path = "snacks.nvim", words = { "Snacks" } },
          { path = vim.fn.stdpath("config") .. "/lua" },
          { path = "lua" },
        },
        -- enabled = function(root_dir)
        --   return not vim.uv.fs_stat(root_dir .. "/.luarc.json")
        -- end,
      },
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
  },
})

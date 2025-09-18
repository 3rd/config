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
    severity_sort = true,
  })

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
  local function root_pattern(...)
    local patterns = { ... }
    return function(startpath)
      return vim.fs.root(startpath or vim.api.nvim_buf_get_name(0), patterns)
    end
  end

  local overrides = {
    -- client.server_capabilities.documentFormattingProvider
    formatting = {
      enable = { "eslint" },
      disable = { "html", "vtsls", "ts_ls" },
    },
  }

  local servers = {
    eslint = {
      enabled = false,
    },
    zls = {},
    bashls = {},
    cssls = {
      settings = {
        css = { lint = { unknownAtRules = "ignore" } },
        scss = { lint = { unknownAtRules = "ignore" } },
      },
    },
    dockerls = {},
    nil_ls = {
      settings = {
        ["nil"] = {
          nix = {
            binary = "nix",
            maxMemoryMB = nil,
            flake = {
              autoEvalInputs = true,
              autoArchive = true,
            },
          },
        },
      },
    },
    gopls = {
      cmd = { "gopls", "-remote=auto", "-remote.debug=:0" },
      settings = {
        gopls = {
          analyses = {
            unusedparams = true,
            unreachable = false,
            ST1003 = false,
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
      root_dir = root_pattern(".root", "package.json") or vim.uv.cwd(),
      filetypes = {
        "javascript",
        "javascriptreact",
        "javascript.jsx",
        "typescript",
        "typescriptreact",
        "typescript.tsx",
      },
      flags = {
        allow_incremental_sync = false,
        debounce_text_changes = 5000,
      },
      -- https://github.com/yioneko/vtsls/blob/main/packages/service/configuration.schema.json
      settings = {
        complete_function_calls = true,
        vtsls = {
          enableMoveToFileCodeAction = true,
          autoUseWorkspaceTsdk = true,
          experimental = {
            maxInlayHintLength = 30,
            completion = {
              enableServerSideFuzzyMatch = true,
              entriesLimit = 150,
            },
          },
        },
        typescript = {
          format = { enable = false },
          tsserver = {
            maxTsServerMemory = "auto",
            -- experimental = { enableProjectDiagnostics = true }, -- this breaks vts by opening unrelated files
          },
          preferences = {
            includePackageJsonAutoImports = "off",
            useAliasesForRenames = true,
          },
          suggest = {
            completeFunctionCalls = true,
          },
          inlayHints = {
            enumMemberValues = { enabled = true },
            functionLikeReturnTypes = { enabled = true },
            parameterNames = { enabled = "literals" },
            parameterTypes = { enabled = true },
            propertyDeclarationTypes = { enabled = true },
            variableTypes = { enabled = true },
          },
          updateImportsOnFileMove = { enabled = "always" },
        },
      },
    },
    -- ts_ls = {
    --   root_dir = root_pattern(".root", "package.json") or vim.uv.cwd(),
    --   -- cmd = { "tsgo", "--lsp", "--stdio" },
    --   -- cmd = { "bunx", "@typescript/native-preview", "--lsp", "--stdio" },
    --   init_options = {
    --     hostInfo = "neovim",
    --     disableAutomaticTypingAcquisition = true,
    --     preferences = {
    --       allowIncompleteCompletions = true,
    --       includeCompletionsForModuleExports = false,
    --       importModuleSpecifierPreference = "shortest",
    --       includePackageJsonAutoImports = "off",
    --       useAliasesForRenames = true,
    --     },
    --     maxTsServerMemory = 2 * 4096,
    --   },
    --   settings = {
    --     javascript = {
    --       format = { enable = false },
    --       preferences = {
    --         useAliasesForRenames = true,
    --       },
    --       parameterNames = { enabled = "literals", suppressWhenArgumentMatchesName = true },
    --       parameterTypes = { enabled = true },
    --       variableTypes = { enabled = true },
    --       propertyDeclarationTypes = { enabled = true },
    --       functionLikeReturnTypes = { enabled = true },
    --       enumMemberValues = { enabled = true },
    --     },
    --     typescript = {
    --       format = { enable = false },
    --       tsserver = {
    --         maxTsServerMemory = "auto",
    --         experimental = { enableProjectDiagnostics = true },
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
    --     ["_typescript.rename"] = function(_, result, ctx)
    --       local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
    --       vim.lsp.util.show_document({
    --         uri = result.textDocument.uri,
    --         range = {
    --           start = result.position,
    --           ["end"] = result.position,
    --         },
    --       }, client.offset_encoding)
    --       vim.lsp.buf.rename()
    --       return vim.NIL
    --     end,
    --   },
    --   commands = {
    --     ["editor.action.showReferences"] = function(command, ctx)
    --       local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
    --       local file_uri, position, references = unpack(command.arguments)
    --
    --       local quickfix_items = vim.lsp.util.locations_to_items(references, client.offset_encoding)
    --       vim.fn.setqflist({}, " ", {
    --         title = command.title,
    --         items = quickfix_items,
    --         context = {
    --           command = command,
    --           bufnr = ctx.bufnr,
    --         },
    --       })
    --
    --       vim.lsp.util.show_document({
    --         uri = file_uri,
    --         range = {
    --           start = position,
    --           ["end"] = position,
    --         },
    --       }, client.offset_encoding)
    --
    --       vim.cmd("botright copen")
    --     end,
    --   },
    -- },
    -- vuels = {
    --   init_options = {
    --     config = {
    --       vetur = {
    --         completion = {
    --           autoImport = true,
    --           tagCasing = "kebab",
    --           useScaffoldSnippets = false,
    --         },
    --         format = { defaultFormatter = { js = "none", ts = "none" } },
    --         useWorkspaceDependencies = false,
    --         validation = { script = true, style = true, template = true },
    --       },
    --     },
    --   },
    -- },
    -- eslint = {
    --   root_dir = root_pattern(".root", "package.json") or vim.uv.cwd(),
    --   cmd = { "vscode-eslint-language-server", "--stdio" },
    --   filetypes = {
    --     "javascript",
    --     "javascriptreact",
    --     "javascript.jsx",
    --     "typescript",
    --     "typescriptreact",
    --     "typescript.tsx",
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
    --     packageManager = "bun",
    --     options = vim.tbl_deep_extend("force", {
    --       cache = true,
    --       cacheLocation = ".eslintcache",
    --       fix = false,
    --       overrideConfigFile = eslintConfigOverride,
    --       resolvePluginsRelativeTo = eslintResolveRelativeTo,
    --     }, eslintConfigOverride and { useEslintrc = false } or {}),
    --     nodePath = eslintResolveRelativeTo,
    --     -- after https://github.com/pmizio/typescript-tools.nvim/pull/302/files
    --     -- + auto local override
    --     -- tsserver_node_executable = "bun",
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
    servers.ast_grep = {
      cmd = { "ast-grep", "lsp" },
      single_file_support = false,
      root_markers = { "sgconfig.yml" },
    }
  end

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
    textDocument = {
      completion = {
        completionItem = {
          snippetSupport = true,
          resolveSupport = {
            properties = { "documentation", "detail", "additionalTextEdits" },
          },
        },
      },
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
  for server_name, server_options in pairs(servers) do
    if server_options.enabled ~= false then
      local config = vim.tbl_deep_extend("force", {
        capabilities = capabilities,
        on_attach = on_attach,
      }, server_options)

      -- add flags
      config.flags = vim.tbl_deep_extend("force", config.flags or {}, {
        allow_incremental_sync = true,
      })

      -- handle special root_dir cases
      if server_name == "vtsls" and not config.root_dir then
        config.root_dir = root_pattern(".root", "package.json") or vim.uv.cwd()
      end

      -- clean up fields not used by vim.lsp.config
      config.enabled = nil

      -- register the config
      vim.lsp.config[server_name] = config
    end
  end

  -- enable all registered servers
  local enabled_servers = {}
  for server_name, server_options in pairs(servers) do
    if server_options.enabled ~= false then table.insert(enabled_servers, server_name) end
  end
  vim.lsp.enable(enabled_servers)

  vim.api.nvim_exec_autocmds("FileType", {})
end

return lib.module.create({
  name = "language-support/lsp",
  hosts = "*",
  setup = function()
    setup()
    -- defer LSP configuration setup
    vim.schedule(setup_lspconfig)
  end,
  plugins = {
    {
      "b0o/schemastore.nvim",
      event = "VeryLazy",
    },
    {
      "dmmulroy/ts-error-translator.nvim",
      event = "VeryLazy",
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
        local function root_pattern(...)
          local patterns = { ... }
          return function(startpath)
            return vim.fs.root(startpath or vim.api.nvim_buf_get_name(0), patterns)
          end
        end

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

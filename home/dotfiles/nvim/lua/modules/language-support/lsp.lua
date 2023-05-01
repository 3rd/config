local config = {
  mason = {
    ui = { border = "rounded" },
  },
  mason_lspconfig = {
    ensure_installed = {
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
      "vtsls",
      "vuels",
      "yamlls",
    },
    ui = {
      icons = {
        server_installed = "✓",
        server_pending = "➜",
        server_uninstalled = "✗",
      },
    },
  },
  lspconfig = {
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
      flags = { allow_incremental_sync = true },
      settings = {
        gopls = {
          analyses = { unusedparams = true, unreachable = false },
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
    golangci_lint_ls = {
      init_options = {
        command = string.split(
          ("golangci-lint run -c %s --out-format json"):format(
            vim.fn.expand("~/.config/nvim/linters/golangci.yml") -- TODO: env dir
          ),
          " "
        ),
      },
    },
    html = {},
    tailwindcss = {},
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
      cmd = { vim.fn.exepath("lua-language-server") },
      settings = {
        Lua = {
          completion = { callSnippet = "Replace" },
          diagnostics = { enable = true, globals = { "vim", "log", "throw" } },
          format = { enable = false },
          workspace = {
            ignoreDir = { "sandbox" },
            checkThirdParty = false,
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
    --       allowIncompleteCompletions = true,
    --       includeCompletionsForModuleExports = true,
    --     },
    --     maxTsServerMemory = 2 * 4096,
    --   },
    --   flags = {
    --     allow_incremental_sync = true,
    --     debounce_text_changes = 150,
    --   },
    --   settings = {
    --     format = { enable = false },
    --     preferences = {
    --       disableSuggestions = true,
    --       quotePreference = "double",
    --       allowIncompleteCompletions = true,
    --       allowRenameOfImportPath = true,
    --       allowTextChangesInNewFiles = true,
    --       displayPartsForJSDoc = false,
    --       generateReturnInDocTemplate = true,
    --       includeAutomaticOptionalChainCompletions = true,
    --       includeCompletionsForImportStatements = true,
    --       includeCompletionsForModuleExports = true,
    --       includeCompletionsWithClassMemberSnippets = true,
    --       includeCompletionsWithObjectLiteralMethodSnippets = true,
    --       includeCompletionsWithInsertText = true,
    --       includeCompletionsWithSnippetText = true,
    --       jsxAttributeCompletionStyle = "auto",
    --       providePrefixAndSuffixTextForRename = true,
    --       provideRefactorNotApplicableReason = true,
    --     },
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
      init_options = {
        hostInfo = "neovim",
        disableAutomaticTypingAcquisition = true,
        preferences = {
          allowIncompleteCompletions = true,
          includeCompletionsForModuleExports = true,
          includePackageJsonAutoImports = "off",
        },
        maxTsServerMemory = 2 * 4096,
      },
      settings = {
        format = { enable = false },
        typescript = {
          preferences = {
            includePackageJsonAutoImports = "off",
          },
        },
        vtsls = {
          experimental = {
            enableProjectDiagnostics = true,
            completion = {
              enableServerSideFuzzyMatch = true,
              entriesLimit = 25,
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
      },
      settings = {
        codeAction = {
          disableRuleComment = { enable = true, location = "separateLine" },
          showDocumentation = { enable = true },
        },
        -- experimental = { useFlatConfig = true },
        nodePath = vim.fn.expand("~/.config/nvim/linters/eslint/node_modules"),
        onIgnoredFiles = "off",
        options = {
          cache = true,
          fix = true,
          overrideConfigFile = vim.fn.expand("~/.config/nvim/linters/eslint/dist/main.js"),
          resolvePluginsRelativeTo = vim.fn.expand("~/.config/nvim/linters/eslint/node_modules"),
          useEslintrc = false,
        },
        packageManager = "npm",
        run = "onType",
        workingDirectory = { mode = "auto" },
      },
    },
    prismals = {},
    cssmodules_ls = {},
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

  -- hover
  -- https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/handlers.lua#L351
  -- vim.lsp.handlers["textDocument/hover"] = function(_, result, ctx, cfg)
  --   cfg = cfg or {}
  --   cfg.focus_id = ctx.method
  --   if not (result and result.contents) then return end
  --   local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
  --   markdown_lines = vim.lsp.util.trim_empty_lines(markdown_lines)
  --   if vim.tbl_isempty(markdown_lines) then return end
  --   return vim.lsp.util.open_floating_preview(markdown_lines, "markdown", cfg)
  -- end
end

local setup_lspconfig = function()
  require("mason").setup(config.mason)
  require("mason-lspconfig").setup(config.mason_lspconfig)

  require("neodev").setup({
    library = {
      plugins = true,
    },
  })

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

  local on_attach = function(client, bufnr)
    -- mappings
    for _, mapping in ipairs(require("config/mappings").lsp) do
      local mode, lhs, rhs, opts_or_desc = mapping[1], mapping[2], mapping[3], mapping[4]
      local opts = lib.is.string(opts_or_desc) and { desc = opts_or_desc } or opts_or_desc or {}
      opts.buffer = bufnr
      lib.map.map(mode, lhs, rhs, opts)
    end

    -- on_attach call hooks
    for _, module in ipairs(modules_with_on_attach_call) do
      module.hooks.lsp.on_attach_call(client, bufnr)
    end
  end

  -- setup servers
  local root_pattern = require("lspconfig.util").root_pattern
  local default_root_dir = root_pattern(".root", ".git", "go.mod", "package.json") or vim.loop.cwd()
  for server_name, server_options in pairs(config.lspconfig) do
    local opts = vim.tbl_deep_extend("force", server_options, {
      capabilities = capabilities,
      on_attach = on_attach,
    })
    opts.flags = opts.flags or {}
    -- opts.flags.debounce_text_changes = 150
    if not opts.root_dir then opts.root_dir = default_root_dir end
    require("lspconfig")[server_name].setup(opts)
  end

  -- on_attach hooks
  for _, module in ipairs(modules_with_on_attach) do
    module.hooks.lsp.on_attach(on_attach)
  end
end

return lib.module.create({
  name = "language-support/lsp",
  setup = setup,
  plugins = {
    {
      "neovim/nvim-lspconfig",
      event = { "BufReadPost", "BufAdd", "BufNewFile" },
      dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "folke/neodev.nvim",
        "ibhagwan/fzf-lua",
      },
      config = setup_lspconfig,
    },
    {
      "j-hui/fidget.nvim",
      event = "BufReadPost",
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

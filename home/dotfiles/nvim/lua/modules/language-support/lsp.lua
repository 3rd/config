local setup = function()
  local lspconfig = require("lspconfig")
  local util = require("lspconfig.util")
  local path = require("plenary.path")
  local schemastore = require("schemastore")
  local lib = require("lib")

  local default_root_dir = util.root_pattern(".root", ".git", "package.json", "go.mod") or vim.loop.cwd()

  local lua_runtime_path = vim.split(package.path, ";")
  table.insert(lua_runtime_path, "lua/?.lua")
  table.insert(lua_runtime_path, "lua/?/init.lua")

  local lua_workspace_library = vim.tbl_extend("keep", {}, {
    vim.fn.expand("$VIMRUNTIME"),
    path:new(vim.fn.stdpath("config"), ".packer", "pack", "packer", "opt", "*"),
    path:new(vim.fn.stdpath("config"), ".packer", "pack", "packer", "start", "*"),
  })

  local config = {
    bashls = { root_dir = default_root_dir },
    cssls = { root_dir = default_root_dir },
    dockerls = { root_dir = default_root_dir },
    gopls = { root_dir = default_root_dir },
    html = { root_dir = default_root_dir },
    rnix = { root_dir = default_root_dir },
    tailwindcss = { root_dir = default_root_dir },
    vimls = { root_dir = default_root_dir },
    astro = { root_dir = default_root_dir },
    intelephense = { root_dir = default_root_dir },
    rust_analyzer = {
      root_dir = default_root_dir,
      settings = {
        ["rust-analyzer"] = {
          assist = { importGranularity = "module", importPrefix = "by_self" },
          cargo = { loadOutDirsFromCheck = true },
          procMacro = { enable = true },
        },
      },
    },
    sumneko_lua = {
      root_dir = default_root_dir,
      cmd = { vim.fn.exepath("lua-language-server") },
      settings = {
        Lua = {
          diagnostics = {
            enable = true,
            globals = { "vim", "log", "throw" },
          },
          runtime = { version = "LuaJIT", path = lua_runtime_path },
          workspace = {
            library = lua_workspace_library,
            maxPreload = 2000,
            preloadFileSize = 50000,
            ignoreDir = { ".undo", "sandbox" },
          },
          telemetry = { enable = false },
        },
      },
    },
    tsserver = {
      root_dir = util.root_pattern(".root", "package.json", ".git") or vim.loop.cwd(),
    },
    vuels = {
      root_dir = util.root_pattern(".root", "package.json", ".git") or vim.loop.cwd(),
      init_options = {
        config = {
          vetur = {
            completion = { autoImport = true, tagCasing = "kebab", useScaffoldSnippets = false },
            format = { defaultFormatter = { js = "none", ts = "none" } },
            useWorkspaceDependencies = false,
            validation = { script = true, style = true, template = true },
          },
        },
      },
    },
    jsonls = {
      root_dir = default_root_dir,
      settings = {
        json = { schemas = schemastore.json.schemas() },
      },
    },
    yamlls = {
      root_dir = default_root_dir,
      settings = {
        json = { schemas = schemastore.json.schemas() },
      },
    },
  }

  local modules_with_capabilities = {}
  for _, module in ipairs(lib.module.get_modules()) do
    if module.hooks and module.hooks.lsp_capabilities then
      table.insert(modules_with_capabilities, module)
    end
  end
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.completion.completionItem.documentationFormat = { "markdown", "plaintext" }
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  capabilities.textDocument.completion.completionItem.preselectSupport = true
  capabilities.textDocument.completion.completionItem.insertReplaceSupport = true
  capabilities.textDocument.completion.completionItem.labelDetailsSupport = true
  capabilities.textDocument.completion.completionItem.deprecatedSupport = true
  capabilities.textDocument.completion.completionItem.commitCharactersSupport = true
  capabilities.textDocument.completion.completionItem.tagSupport = { valueSet = { 1 } }
  capabilities.textDocument.completion.completionItem.resolveSupport = {
    properties = { "documentation", "detail", "additionalTextEdits" },
  }
  capabilities.textDocument.foldingRange = { dynamicRegistration = false, lineFoldingOnly = true }
  capabilities.textDocument.hover = { contentFormat = { "markdown", "plaintext" } }
  for _, module in ipairs(modules_with_capabilities) do
    capabilities = vim.lsp.protocol.merge_capabilities(capabilities, module.hooks.lsp_capabilities())
  end

  local modules_with_lsp_on_attach = {}
  for _, module in ipairs(lib.module.get_modules()) do
    if module.hooks and module.hooks.lsp_on_attach then
      table.insert(modules_with_lsp_on_attach, module)
    end
  end

  local on_attach = function(client)
    for _, module in ipairs(modules_with_lsp_on_attach) do
      module.hooks.lsp_on_attach(client)
    end

    vim.keymap.set("n", "gd", "<cmd>lua vim.lsp.buf.definition()<cr>", { buffer = true })
    vim.keymap.set("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<cr>", { buffer = true })
    vim.keymap.set("n", "gt", "<cmd>lua vim.lsp.buf.type_definition()<cr>", { buffer = true })
    vim.keymap.set("n", "<leader>r", ":Telescope lsp_document_symbols<cr>", { buffer = true })
    vim.keymap.set("n", "<leader>R", ":Telescope lsp_dynamic_workspace_symbols<cr>", { buffer = true })
    vim.keymap.set("n", "K", "<cmd>lua vim.lsp.buf.hover()<cr>", { buffer = true })
    vim.keymap.set("n", "gr", ":Telescope lsp_references<cr>", { buffer = true })
    vim.keymap.set("n", "<leader>ac", "<cmd>lua vim.lsp.buf.code_action()<cr>", { buffer = true })
    vim.keymap.set("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<cr>", { buffer = true })
    vim.keymap.set("n", "gp", "<cmd>lua vim.diagnostic.goto_next()<cr>", { buffer = true })
    vim.keymap.set("n", "gP", "<cmd>lua vim.diagnostic.goto_prev()<cr>", { buffer = true })
    vim.keymap.set("n", "<leader>er", "<cmd>lua vim.lsp.buf.rename()<cr>", { buffer = true })
  end

  require("modules/language-support/null-ls").export.setup(on_attach)

  for server_name, server in pairs(config) do
    local opts = server
    opts.on_attach = on_attach
    opts.flags = { debounce_text_changes = 101 }
    opts.capabilities = capabilities
    lspconfig[server_name].setup(opts)
  end

  local mason_lsp_config = {
    ensure_installed = {
      "bashls",
      "clangd",
      "cssls",
      "dockerls",
      "gopls",
      "html",
      "jsonls",
      "rust_analyzer",
      "tailwindcss",
      "tsserver",
      "vimls",
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
  }

  require("mason").setup()
  require("mason-lspconfig").setup(mason_lsp_config)
end

return require("lib").module.create({
  name = "language-support/lsp",
  plugins = {
    {
      "neovim/nvim-lspconfig",
      requires = {
        "nvim-lua/plenary.nvim",
        "b0o/schemastore.nvim",
        "jose-elias-alvarez/null-ls.nvim",
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
      },
      config = setup,
    },
  },
})

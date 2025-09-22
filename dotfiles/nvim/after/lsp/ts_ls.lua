return {
  -- cmd = { "tsgo", "--lsp", "--stdio" },
  -- cmd = { "bunx", "@typescript/native-preview", "--lsp", "--stdio" },
  root_dir = function(bufnr, on_dir)
    local root_markers = { ".root", "package.json", "tsconfig.json", ".git" }
    root_markers = vim.list_extend(root_markers, { ".git" })
    flog("before")
    local project_root = vim.fs.root(bufnr, root_markers) or vim.fn.getcwd()
    flog("root:", project_root)
    on_dir(project_root)
  end,
  init_options = {
    hostInfo = "neovim",
    disableAutomaticTypingAcquisition = true,
    preferences = {
      allowIncompleteCompletions = true,
      includeCompletionsForModuleExports = false,
      importModuleSpecifierPreference = "shortest",
      includePackageJsonAutoImports = "off",
      useAliasesForRenames = true,
    },
    maxTsServerMemory = 2 * 4096,
  },
  settings = {
    javascript = {
      format = { enable = false },
      preferences = {
        useAliasesForRenames = true,
      },
      parameterNames = { enabled = "literals", suppressWhenArgumentMatchesName = true },
      parameterTypes = { enabled = true },
      variableTypes = { enabled = true },
      propertyDeclarationTypes = { enabled = true },
      functionLikeReturnTypes = { enabled = true },
      enumMemberValues = { enabled = true },
    },
    typescript = {
      format = { enable = false },
      tsserver = {
        maxTsServerMemory = "auto",
        experimental = { enableProjectDiagnostics = true },
      },
      preferences = {
        includePackageJsonAutoImports = "off",
        useAliasesForRenames = true,
      },
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
      updateImportsOnFileMove = {
        enabled = "always",
      },
    },
  },
  handlers = {
    -- always go to the first definition
    ["textDocument/definition"] = function(err, result, ...)
      if vim.islist(result) or type(result) == "table" then result = result[1] end
      vim.lsp.handlers["textDocument/definition"](err, result, ...)
    end,
    ["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
      if ctx.client_id == "vtsls" then
        require("ts-error-translator").translate_diagnostics(err, result, ctx, config)
      end
      vim.lsp.handlers["textDocument/publishDiagnostics"](err, result, ctx, config)
    end,
    ["_typescript.rename"] = function(_, result, ctx)
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      vim.lsp.util.show_document({
        uri = result.textDocument.uri,
        range = {
          start = result.position,
          ["end"] = result.position,
        },
      }, client.offset_encoding)
      vim.lsp.buf.rename()
      return vim.NIL
    end,
  },
  commands = {
    ["editor.action.showReferences"] = function(command, ctx)
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      local file_uri, position, references = unpack(command.arguments)

      local quickfix_items = vim.lsp.util.locations_to_items(references, client.offset_encoding)
      vim.fn.setqflist({}, " ", {
        title = command.title,
        items = quickfix_items,
        context = {
          command = command,
          bufnr = ctx.bufnr,
        },
      })

      vim.lsp.util.show_document({
        uri = file_uri,
        range = {
          start = position,
          ["end"] = position,
        },
      }, client.offset_encoding)

      vim.cmd("botright copen")
    end,
  },
}

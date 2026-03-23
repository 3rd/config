local inlay_hints = {
  parameterNames = { enabled = "literals", suppressWhenArgumentMatchesName = true },
  parameterTypes = { enabled = true },
  variableTypes = { enabled = true },
  propertyDeclarationTypes = { enabled = true },
  functionLikeReturnTypes = { enabled = true },
  enumMemberValues = { enabled = true },
}

return {
  init_options = {
    hostInfo = "neovim",
    disableAutomaticTypingAcquisition = true,
    tsserver = {
      useSyntaxServer = "never",
    },
    preferences = {
      allowIncompleteCompletions = true,
      includeCompletionsForModuleExports = true,
      includeCompletionsForImportStatements = true,
      importModuleSpecifierPreference = "shortest",
      includePackageJsonAutoImports = "off",
      useAliasesForRenames = true,
    },
  },
  settings = {
    javascript = {
      format = { enable = false },
      preferences = {
        includePackageJsonAutoImports = "off",
        useAliasesForRenames = true,
      },
      inlayHints = inlay_hints,
    },
    typescript = {
      format = { enable = false },
      preferences = {
        includePackageJsonAutoImports = "off",
        useAliasesForRenames = true,
      },
      inlayHints = inlay_hints,
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

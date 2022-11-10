local setup = function()
  local cmp = require("cmp")
  local luasnip = require("luasnip")
  local lspkind = require("lspkind")

  local highlights = {
    CmpItemAbbr = { fg = "#565c64", bg = "NONE" },
    CmpItemKindSnippet = { fg = "#565c64" },
    CmpItemAbbrMatch = { fg = "#569CD6", bg = "NONE" },
    CmpItemAbbrMatchFuzzy = { fg = "#569CD6", bg = "NONE" },
    CmpItemKindClass = { fg = "Orange" },
    CmpItemKindConstructor = { fg = "#ae43f0" },
    CmpItemKindFolder = { fg = "#2986cc" },
    CmpItemKindReference = { fg = "#922b21" },
    CmpItemKindInterface = { fg = "#9CDCFE", bg = "NONE" },
    CmpItemKindText = { fg = "#9CDCFE" },
    CmpItemKindVariable = { fg = "#9CDCFE", bg = "NONE" },
    CmpItemKindFunction = { fg = "#C586C0" },
    CmpItemKindMethod = { fg = "#C586C0" },
    CmpItemMenu = { fg = "#C586C0", bg = "#C586C0" },
    CmpItemKindKeyword = { fg = "#D4D4D4" },
    CmpItemKindProperty = { fg = "#D4D4D4", bg = "NONE" },
    CmpItemKindUnit = { fg = "#D4D4D4", bg = "NONE" },
  }

  local config = {
    auto_select = true,
    formatting = {
      format = lspkind.cmp_format({
        with_text = true,
        maxwidth = 50,
      }),
    },
    completion = {
      keyword_length = 1,
      max_item_count = 20,
      autocomplete = { require("cmp.types").cmp.TriggerEvent.TextChanged },
    },
    performance = {
      debounce = 60,
      throttle = 100,
      fetching_timeout = 200,
    },
    snippet = {
      expand = function(args) luasnip.lsp_expand(args.body) end,
    },
    enabled = function()
      -- disable completion in comments
      -- local context = require("cmp.config.context")
      -- return not context.in_treesitter_capture("comment") and not context.in_syntax_group("Comment")
      return true
    end,
    mapping = {
      ["<CR>"] = cmp.mapping.confirm({ select = false }),
      ["<Tab>"] = function(fallback)
        if cmp.visible() then
          cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
        elseif luasnip.expand_or_jumpable() then
          luasnip.expand_or_jump()
        else
          local ok, suggestion = pcall(require, "copilot.suggestion")
          if ok and suggestion.is_visible() then
            suggestion.accept()
          else
            fallback()
          end
        end
      end,
      ["<S-Tab>"] = function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          return fallback()
        end
      end,
      ["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
      ["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(4), { "i", "c" }),
      ["<C-u>"] = cmp.mapping(cmp.mapping.scroll_docs(-4), { "i", "c" }),
    },
    sources = cmp.config.sources({
      { name = "luasnip", keyword_length = 2 },
      { name = "nvim_lsp" },
      { name = "path", keyword_length = 2 },
      -- { name = "buffer", priority_weight = 60 },
    }),
    window = {
      completion = {
        border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
        -- border = { "🭽", "▔", "🭾", "▕", "🭿", "▁", "🭼", "▏" },
        -- border = "rounded",
        winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder",
        scrollbar = "║",
        autocomplete = {
          require("cmp.types").cmp.TriggerEvent.InsertEnter,
          require("cmp.types").cmp.TriggerEvent.TextChanged,
        },
      },
      documentation = {
        border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
        winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder",
        scrollbar = "║",
      },
    },
    style = { winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder" },
    experimental = { ghost_text = false },
    sorting = {
      comparators = {
        cmp.config.compare.recently_used,
        cmp.config.compare.offset,
        cmp.config.compare.score,
        cmp.config.compare.sort_text,
        cmp.config.compare.length,
        cmp.config.compare.order,
      },
    },
    preselect = cmp.PreselectMode.Item,
  }

  cmp.setup(config)
  -- cmp.setup.cmdline("/", { sources = { { name = "buffer" } } })
  -- cmp.setup.cmdline(":", { sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }) })

  vim.api.nvim_set_hl(0, "CmpBorderedWindow_FloatBorder", { fg = "#565c64" })
  for group, hl in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, hl)
  end
end

local patch_capabilities =
  function(capabilities) return require("cmp_nvim_lsp").update_capabilities(capabilities) end

return require("lib").module.create({
  name = "completion/nvim-cmp",
  plugins = {
    {
      "hrsh7th/nvim-cmp",
      event = "InsertEnter",
      requires = {
        { "onsails/lspkind-nvim" },
      },
      config = setup,
    },
    { "hrsh7th/cmp-nvim-lsp", after = "nvim-cmp" },
    { "hrsh7th/cmp-path", after = "nvim-cmp" },
    { "saadparwaiz1/cmp_luasnip", after = "nvim-cmp" },
  },
  hooks = {
    capabilities = patch_capabilities,
  },
})

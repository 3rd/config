-- https://github.com/stevearc/conform.nvim/issues/36
-- requirecwd https://github.com/stevearc/conform.nvim/issues/72
-- https://github.com/chrisgrieser/.config/blob/7dc36c350976010b32ece078edd581687634811a/nvim/lua/plugins/linter-formatter.lua#L27-L82

local paths = {
  stylua_config = lib.path.resolve_config("linters/stylua.toml"),
  prettier_config = lib.path.resolve_config("linters/prettier.json"),
}

local web_formatters = {
  "prettierd",
  "rustywind",
  -- "eslint_d",
}
local fts_with_lsp_formatting = {
  "typescript",
  "typescriptreact",
  "javascript",
  "javascriptreact",
}

return lib.module.create({
  name = "language-support/formatting",
  hosts = "*",
  plugins = {
    {
      "stevearc/conform.nvim",
      event = { "BufReadPre", "BufNewFile" },
      config = function()
        local conform = require("conform")
        local slow_format_filetypes = {}

        local config = {
          notify_on_error = false,
          formatters_by_ft = {
            lua = { "stylua" },
            nix = { "nixfmt" },
            go = { "goimports", "gofmt" },
            rust = { "rustfmt" },
            sh = { "shfmt" },
            typescript = web_formatters,
            typescriptreact = web_formatters,
            javascript = web_formatters,
            javascriptreact = web_formatters,
            astro = web_formatters,
            css = web_formatters,
            json = { "fixjson", "prettierd" },
            jsonc = { "fixjson", "prettierd" },
            html = { "prettierd" },
            yaml = { "prettierd" },
            markdown = { "prettierd" },
            graphql = { "prettierd" },
          },
          formatters = {
            stylua = {
              prepend_args = lib.path.root_has(".stylua.toml", "stylua.toml") and {}
                or { "--config-path", paths.stylua_config },
            },
            shfmt = {
              prepend_args = { "-i", "2", "-ci", "-bn" },
            },
            prettierd = {
              env = { PRETTIERD_DEFAULT_CONFIG = paths.prettier_config },
            },
            -- eslint_d = {
            --   args = {
            --     "--fix-to-stdout",
            --     "--config",
            --     lib.path.resolve_config("linters/eslint/dist/main.js"),
            --     "--no-eslintrc",
            --     "--stdin",
            --     "--stdin-filename",
            --     "$FILENAME",
            --   },
            --   env = {
            --     ESLINT_USE_FLAT_CONFIG = "false",
            --     ESLINT_D_ROOT = lib.path.resolve_config("linters/eslint"),
            --   },
            -- },
          },
        }

        local function filter_formatters(ft)
          local formatters = config.formatters_by_ft[ft]
          if not formatters then return nil end

          local filtered = {}
          for _, formatter in ipairs(formatters) do
            -- $cwd/.noformat disables prettier
            if vim.fn.filereadable(lib.path.resolve(lib.path.cwd(), ".noformat")) == 1 then
              if formatter == "prettierd" then goto continue end
            end
            vim.list_extend(filtered, { formatter })
            ::continue::
          end
          return filtered
        end

        config.format_on_save = function(bufnr)
          if slow_format_filetypes[vim.bo[bufnr].filetype] then return end

          local function on_format(err)
            if err and err:match("timeout$") then slow_format_filetypes[vim.bo[bufnr].filetype] = true end
          end

          return {
            timeout_ms = 2000,
            lsp_fallback = vim.tbl_contains(fts_with_lsp_formatting, vim.bo[bufnr].filetype) and "always" or true,
            formatters = filter_formatters(vim.bo[bufnr].filetype),
          },
            on_format
        end

        config.format_after_save = function(bufnr)
          if not slow_format_filetypes[vim.bo[bufnr].filetype] then return end
          return {
            lsp_fallback = vim.tbl_contains(fts_with_lsp_formatting, vim.bo[bufnr].filetype) and "always" or true,
            formatters = filter_formatters(vim.bo[bufnr].filetype),
          }
        end

        conform.setup(config)

        vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
      end,
    },
  },
})

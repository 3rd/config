return lib.module.create({
  name = "language-support/linting",
  hosts = "*",
  plugins = {
    {
      "mfussenegger/nvim-lint",
      event = "VeryLazy",
      dependencies = { "mason-org/mason.nvim" },
      config = function()
        local lint = require("lint")
        local has_jit, jit = pcall(require, "jit")
        local is_arm64 = has_jit and jit.arch == "arm64"

        lint.linters.selene.args = {
          "--display-style",
          "json",
          "--config",
          lib.path.resolve(lib.env.dirs.vim.config, "linters/selene.toml"),
          "-",
        }

        lint.linters_by_ft = {
          nix = { "nix", "statix" },
          cpp = { "cppcheck" },
          markdown = {
            -- "alex",
          },
          sh = { "shellcheck" },
          lua = is_arm64 and {} or { "selene" },
        }

        local group = vim.api.nvim_create_augroup("lint", { clear = true })
        local lint_generation = {}
        local last_linted_tick = {}

        local is_lintable_buffer = function(bufnr)
          if not bufnr or bufnr <= 0 then return false end
          if not vim.api.nvim_buf_is_valid(bufnr) then return false end
          if vim.bo[bufnr].buftype ~= "" then return false end
          if vim.bo[bufnr].filetype == "" then return false end
          return true
        end

        local lint_buffer = function(bufnr, force)
          if not is_lintable_buffer(bufnr) then return end

          local ok_tick, changedtick = pcall(vim.api.nvim_buf_get_changedtick, bufnr)
          if not ok_tick then return end
          if not force and last_linted_tick[bufnr] == changedtick then return end

          local ok_lint = pcall(vim.api.nvim_buf_call, bufnr, function()
            lint.try_lint()
          end)
          if not ok_lint then return end

          local ok_latest_tick, latest_tick = pcall(vim.api.nvim_buf_get_changedtick, bufnr)
          if ok_latest_tick then last_linted_tick[bufnr] = latest_tick end
        end

        local schedule_lint = function(bufnr, opts)
          opts = opts or {}
          if not is_lintable_buffer(bufnr) then return end

          local debounce_ms = opts.debounce_ms or 0
          local force = opts.force == true

          if debounce_ms <= 0 then
            lint_buffer(bufnr, force)
            return
          end

          local generation = (lint_generation[bufnr] or 0) + 1
          lint_generation[bufnr] = generation

          vim.defer_fn(function()
            if lint_generation[bufnr] ~= generation then return end
            lint_buffer(bufnr, force)
          end, debounce_ms)
        end

        vim.api.nvim_create_autocmd("BufReadPost", {
          group = group,
          callback = function(args)
            schedule_lint(args.buf, { force = true })
          end,
        })

        vim.api.nvim_create_autocmd("BufWritePost", {
          group = group,
          callback = function(args)
            schedule_lint(args.buf, { force = true })
          end,
        })

        vim.api.nvim_create_autocmd("InsertLeave", {
          group = group,
          callback = function(args)
            schedule_lint(args.buf, { debounce_ms = 150, force = false })
          end,
        })

        vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
          group = group,
          callback = function(args)
            lint_generation[args.buf] = nil
            last_linted_tick[args.buf] = nil
          end,
        })
      end,
    },
  },
})

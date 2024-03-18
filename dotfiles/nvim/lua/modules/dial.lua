return lib.module.create({
  name = "dial",
  enabled = false,
  plugins = {
    {
      "monaqa/dial.nvim",
      keys = {
        { "<C-a>", "<Plug>(dial-increment)", mode = { "n", "v" } },
        { "<C-x>", "<Plug>(dial-decrement)", mode = { "n", "v" } },
        { "g<C-a>", "g<Plug>(dial-increment)", mode = { "n", "v" }, remap = true },
        { "g<C-x>", "g<Plug>(dial-decrement)", mode = { "n", "v" }, remap = true },
      },
      config = function()
        local augend = require("dial.augend")

        local logical_alias = augend.constant.new({
          elements = { "&&", "||" },
          word = false,
          cyclic = true,
        })

        local ordinalNumbers = augend.constant.new({
          elements = {
            "first",
            "second",
            "third",
            "fourth",
            "fifth",
            "sixth",
            "seventh",
            "eighth",
            "ninth",
            "tenth",
          },
          word = false,
          cyclic = true,
        })

        local weekdays = augend.constant.new({
          elements = {
            "Monday",
            "Tuesday",
            "Wednesday",
            "Thursday",
            "Friday",
            "Saturday",
            "Sunday",
          },
          word = true,
          cyclic = true,
        })

        local months = augend.constant.new({
          elements = {
            "January",
            "February",
            "March",
            "April",
            "May",
            "June",
            "July",
            "August",
            "September",
            "October",
            "November",
            "December",
          },
          word = true,
          cyclic = true,
        })

        require("dial.config").augends:register_group({
          default = {
            augend.date.alias["%Y/%m/%d"], -- date (2022/02/19, etc.)
            augend.integer.alias.decimal, -- nonnegative decimal number (0, 1, 2, 3, ...)
            augend.integer.alias.hex, -- nonnegative hex number  (0x01, 0x1a1f, etc.)
          },
          syslang = {
            months,
            ordinalNumbers,
            weekdays,
          },
          typescript = {
            augend.constant.alias.bool, -- boolean value (true <-> false)
            augend.constant.new({ elements = { "let", "const" } }),
            augend.integer.alias.decimal, -- nonnegative and negative decimal number
            logical_alias,
            months,
            ordinalNumbers,
            weekdays,
          },
          css = {
            augend.hexcolor.new({ case = "lower" }),
            augend.hexcolor.new({ case = "upper" }),
            augend.integer.alias.decimal, -- nonnegative and negative decimal number
          },
          markdown = {
            augend.misc.alias.markdown_header,
            months,
            ordinalNumbers,
            weekdays,
          },
          json = {
            augend.integer.alias.decimal, -- nonnegative and negative decimal number
            augend.semver.alias.semver, -- versioning (v1.1.2)
          },
          lua = {
            augend.integer.alias.decimal, -- nonnegative and negative decimal number
            augend.constant.alias.bool, -- boolean value (true <-> false)
            augend.constant.new({
              elements = { "and", "or" },
              word = true, -- if false, "sand" is incremented into "sor", "doctor" into "doctand", etc.
              cyclic = true, -- "or" is incremented into "and".
            }),
            ordinalNumbers,
            weekdays,
            months,
          },
        })

        local set_dial_group = function(lang)
          vim.api.nvim_buf_set_keymap(0, "n", "<C-a>", require("dial.map").inc_normal(lang))
          vim.api.nvim_buf_set_keymap(0, "v", "<C-a>", require("dial.map").inc_visual(lang))

          vim.api.nvim_buf_set_keymap(0, "n", "<C-x>", require("dial.map").dec_normal(lang))
          vim.api.nvim_buf_set_keymap(0, "v", "<C-x>", require("dial.map").dec_visual(lang))

          vim.api.nvim_buf_set_keymap(0, "n", "g<C-a>", require("dial.map").inc_gnormal(lang))
          vim.api.nvim_buf_set_keymap(0, "v", "g<C-a>", require("dial.map").inc_gvisual(lang))

          vim.api.nvim_buf_set_keymap(0, "n", "g<C-x>", require("dial.map").dec_gnormal(lang))
          vim.api.nvim_buf_set_keymap(0, "v", "g<C-x>", require("dial.map").dec_gvisual(lang))
        end

        local dial_augroup = vim.api.nvim_create_augroup("DialFileType", { clear = true })

        local filetypes = {
          typescript = {
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
          },
          css = { "css", "scss", "sass" },
          markdown = { "markdown" },
          syslang = { "syslang" },
          json = { "json" },
          lua = { "lua" },
        }

        for lang, patterns in pairs(filetypes) do
          vim.api.nvim_create_autocmd("FileType", {
            group = dial_augroup,
            pattern = patterns,
            callback = function()
              set_dial_group(lang)
            end,
          })
        end
      end,
    },
  },
})

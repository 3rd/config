return lib.module.create({
  -- enabled = false,
  name = "syslang",
  plugins = {
    {
      dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "syslang"),
      ft = "syslang",
      init = function()
        vim.filetype.add({
          pattern = {
            [".*"] = {
              priority = -math.huge,
              function(_, bufnr)
                -- abort if executable
                if lib.fs.file.is_executable(vim.api.nvim_buf_get_name(bufnr)) then return end

                -- abort if filetype already set
                if lib.buffer.get_option(bufnr, "filetype") ~= "" then return end

                -- abort scratch
                if not vim.api.nvim_buf_get_option(bufnr, "buflisted") then return end
                if vim.api.nvim_buf_get_option(bufnr, "bufhidden") ~= "" then return end
                if vim.api.nvim_buf_get_name(bufnr) == "" then return end

                -- abort if floating window
                local ok, win = pcall(vim.api.nvim_win_get_config, 0)
                if ok and win.relative ~= "" then return end

                -- abort if path has extension != syslang
                local path_parts = string.split(vim.api.nvim_buf_get_name(bufnr), "/")
                local filename = path_parts[#path_parts]
                local extension_parts = string.split(filename, ".")
                local extension = extension_parts[#extension_parts]
                if filename ~= extension and extension ~= "syslang" then return end

                -- setf
                return "syslang"
              end,
            },
          },
        })
      end,
    },
  },
})

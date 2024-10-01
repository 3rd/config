return lib.module.create({
  name = "core/syslang",
  -- enabled = false,
  hosts = "*",
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
                if not vim.api.nvim_get_option_value("buflisted", { buf = bufnr }) then return end
                if vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ~= "" then return end
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

                -- abort if not file
                local path = vim.api.nvim_buf_get_name(bufnr)
                local f = io.open(path, "r") -- Attempt to open the file
                if f then
                  f.close(f) -- Close file if we opened it ok
                else
                  return
                end

                -- abort if filename matches [A-Z][a-z]*file
                if filename:match("^[A-Z][a-z]*file$") then return end

                -- abort if not in ~/brain
                -- if not path:find(lib.env.dirs.home .. "/brain") then return end

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

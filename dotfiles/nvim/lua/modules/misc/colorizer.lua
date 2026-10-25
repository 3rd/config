local add_tailwind_filetypes = function(filetypes)
  local result = vim.deepcopy(filetypes)
  for _, filetype in ipairs(vim.lsp.config.tailwindcss.filetypes) do
    result[filetype] = { parsers = { tailwind = { enable = true, update_names = true } } }
  end
  return result
end

return lib.module.create({
  name = "misc/colorizer",
  hosts = "*",
  plugins = {
    {
      "catgoose/nvim-colorizer.lua",
      event = "BufReadPre",
      opts = {
        filetypes = { "*" },
        options = {
          parsers = {
            names = { enable = false },
            hex = {
              default = true,
              rgb = true,
              rgba = true,
              rrggbb = true,
              rrggbbaa = true,
              aarrggbb = true,
            },
            rgb = { enable = true },
            hsl = { enable = true },
            oklch = { enable = true },
            tailwind = { enable = false },
            xterm = { enable = true },
          },
          display = {
            mode = "background",
            priority = { default = vim.hl.priorities.user },
            virtualtext = {
              char = "■",
              position = "eol",
              hl_mode = "foreground",
            },
          },
          always_update = false,
          debounce_ms = 30,
        },
      },
      config = function(_, opts)
        require("colorizer").setup(
          vim.tbl_extend("force", opts, { filetypes = add_tailwind_filetypes(opts.filetypes) })
        )
      end,
    },
  },
})

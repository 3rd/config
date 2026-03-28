local get_picker = function()
  return require("modules/workflow/fzf").exports
end

local find_files = function(opts)
  get_picker().find_files(opts)
end

local live_grep = function(opts)
  get_picker().live_grep(opts)
end

local live_grep_selection = function()
  get_picker().live_grep_selection()
end

local buffers = function(opts)
  get_picker().buffers(opts)
end

local buffer_lines = function(opts)
  get_picker().buffer_lines(opts)
end

local lines = function(opts)
  get_picker().lines(opts)
end

local resume = function()
  get_picker().resume()
end

local references = function(opts)
  get_picker().lsp_references(opts)
end

local workspace_symbols = function(opts)
  get_picker().lsp_workspace_symbols(opts)
end

local wiki = function()
  live_grep({
    cwd = vim.fs.normalize(vim.env.HOME .. "/brain/wiki"),
    title = "Wiki",
  })
end

local search_replace = function()
  local grug = require("grug-far")
  local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
  grug.open({
    transient = true,
    prefills = {
      filesFilter = ext and ext ~= "" and "*." .. ext or nil,
    },
  })
end

local setup = function()
  vim.api.nvim_create_user_command("SearchFiles", function()
    find_files()
  end, { desc = "Find file in project" })
  vim.api.nvim_create_user_command("SearchGrep", function()
    live_grep()
  end, { desc = "Find text in project" })
  vim.api.nvim_create_user_command("SearchResume", function()
    resume()
  end, { desc = "Resume last search picker" })
  vim.api.nvim_create_user_command("SearchBuffers", function()
    buffers()
  end, { desc = "Find buffer" })
  vim.api.nvim_create_user_command("SearchReferences", function()
    references()
  end, { desc = "LSP: Go to references" })
  vim.api.nvim_create_user_command("SearchWorkspaceSymbols", function()
    workspace_symbols()
  end, { desc = "LSP: Show workspace symbols" })
  vim.api.nvim_create_user_command("SearchWiki", function()
    wiki()
  end, { desc = "Find text in wiki" })
end

return lib.module.create({
  name = "workflow/search",
  hosts = "*",
  setup = setup,
  plugins = {
    {
      "MagicDuck/grug-far.nvim",
      opts = { headerMaxWidth = 80 },
      cmd = "GrugFar",
      keys = {
        {
          "<C-S-f>",
          search_replace,
          mode = { "n", "v" },
          desc = "Search and Replace",
        },
      },
    },
  },
  exports = {
    find_files = find_files,
    grep = live_grep,
    grep_selection = live_grep_selection,
    buffers = buffers,
    buffer_lines = buffer_lines,
    lines = lines,
    resume = resume,
    references = references,
    workspace_symbols = workspace_symbols,
    wiki = wiki,
    replace = search_replace,
  },
})

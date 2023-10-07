local api = {
  get = function(id)
    local command = string.format("WIKI_ROOT=$HOME/brain/wiki TASK_ROOT=$HOME/brain/wiki core wiki resolve '%s'", id)
    return lib.shell.exec(command)
  end,
  list = function()
    local command = "WIKI_ROOT=$HOME/brain/wiki TASK_ROOT=$HOME/brain/wiki core wiki ls | sort"
    local entries = string.split(lib.shell.exec(command), "\n")
    return entries
  end,
}

local handle_select = function()
  local entries = api.list()

  local fzf = require("fzf")
  coroutine.wrap(function()
    local win_options = { height = 10, relative = "win" }
    vim.cmd([[20 new]])
    local result =
      fzf.provided_win_fzf(entries, "--print-query --nth 1 --print-query --expect=ctrl-s,ctrl-v,ctrl-x", win_options)
    if not result then return end

    local target = result[3]

    local command = "e %s"
    if result[2] == "ctrl-s" then
      command = "sp %s"
    elseif result[2] == "ctrl-v" then
      command = "vs %s"
    elseif result[2] == "ctrl-x" then
      target = result[1]
    end

    local path = api.get(target)
    local vim_command = string.format(command, path)
    vim.cmd(vim_command)
  end)()
end

local handle_search = function()
  require("fzf-lua").grep_project({
    cwd = vim.env.HOME .. "/brain/wiki",
  })
end

local handle_navigate_to_symbol = function()
  local parser = vim.treesitter.get_parser()
  local root = parser:parse()[1]:root()

  local kinds = {
    "heading_1",
    "heading_2",
    "heading_3",
    "heading_4",
    "heading_5",
    "heading_6",
  }
  local symbols = lib.ts.find_children(root, kinds, true)

  local entries = {}
  for _, symbol in ipairs(symbols) do
    local text = vim.treesitter.get_node_text(symbol, 0)
    local first_line = string.split(text, "\n")[1]
    local row = symbol:start()
    table.insert(entries, string.format("%s: %s", row + 1, first_line))
  end

  local fzf = require("fzf")
  local current_file = vim.fn.expand("%:p")

  coroutine.wrap(function()
    local win_options = { height = 10, relative = "win" }
    vim.cmd([[20 new]])

    local preview =
      string.format([[bat --style=numbers --color=always --line-range (echo {} | cut -d: -f1): %s]], current_file)
    local options = "--print-query --nth 3.. --preview '" .. preview .. "' --preview-window right:50%"

    local result = fzf.provided_win_fzf(entries, options, win_options)
    if not result then return end

    local target = result[2]
    local row = string.split(target, ":")[1]

    vim.schedule(function()
      vim.api.nvim_win_set_cursor(0, { row + 0, 0 })
    end)
  end)()
end

local get_asset_dir = function()
  local cwd = vim.fn.getcwd()
  ---@type string|nil
  local asset_dir = cwd .. "/_media/images"
  if vim.fn.isdirectory(asset_dir) == 0 then asset_dir = nil end
  return asset_dir
end

local get_image_path = function()
  local relative_path = vim.fn.expand("%:t:r") .. "-" .. os.time() .. ".png"
  local asset_dir = get_asset_dir()
  if asset_dir then return vim.fn.expand(asset_dir .. "/" .. relative_path) end
  return vim.fn.expand("%:p:h") .. "/" .. relative_path
end

local handle_paste = function()
  local clipboard_content = lib.shell.exec("xclip -selection clipboard -o -t TARGETS")

  local is_image = string.match(clipboard_content, "image/")
  -- local is_text = string.match(clipboard_content, "UTF8_STRING")

  if is_image then
    -- input name
    -- vim.fn.inputsave()
    -- local name = vim.fn.input("Name: ")
    -- vim.fn.inputrestore()
    -- if not name or name == "" then return end
    -- compute path
    -- local current_file = vim.fn.expand("%:p")
    -- ---@cast current_file string
    -- local current_dir = vim.fn.fnamemodify(current_file, ":h")
    -- local path = current_dir .. "/" .. name .. ".png"

    local path = get_image_path()

    -- write image to file
    local command = string.format("xclip -selection clipboard -t image/png -o > '%s'", path)
    lib.shell.exec(command)

    -- insert image
    local alt_date = os.date("%Y-%m-%d %H:%M")
    local alt = "Paste: " .. alt_date
    local formatted_image = string.format("![%s](%s)", alt, path)
    vim.fn.setreg("+", formatted_image)
    vim.cmd("normal! p")
    return
  end

  -- fallback
  vim.cmd("normal! p")
end

local setup = function()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("wiki-syslang", {}),
    pattern = "syslang",
    callback = function()
      lib.map.map("n", "<leader>r", handle_navigate_to_symbol, { desc = "Navigate to symbol", buffer = true })
      lib.map.map("n", "p", handle_paste, { desc = "Paste", buffer = true })
    end,
  })
end

return lib.module.create({
  name = "wiki",
  setup = setup,
  mappings = {
    { "n", "<M-n>", handle_select },
    { "n", "<M-m>", handle_search },
  },
})

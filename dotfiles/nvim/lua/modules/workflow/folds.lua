local enable_slang_meta = true

local get_upper_fold_level = function()
  local winview = vim.fn.winsaveview()
  local foldlevel = -1
  local ok = pcall(vim.cmd, "keepjumps normal! [z")
  if ok then foldlevel = vim.fn.foldlevel(vim.fn.line(".")) end
  if winview then vim.fn.winrestview(winview) end
  return foldlevel
end

local is_current_line_in_open_fold_and_is_not_first = function()
  local is_closed_fold = vim.fn.foldclosed(vim.fn.line(".")) ~= -1

  local foldlevel = vim.fn.foldlevel(vim.fn.line("."))
  local upper_foldlevel = get_upper_fold_level()

  return foldlevel == upper_foldlevel or is_closed_fold and foldlevel > upper_foldlevel
end

local setup_ufo = function()
  local config = {
    -- folded_info_prefix = " ",
    folded_info_prefix = "... ",
    -- folded_info_prefix = "…  ",
    show_folded_line_count = false,
    chars = {
      outline = "◉",
      section_collapsed = "▶",
      section_expanded = "▼",
      list_item = "•",
      task_default = "",
      task_active = "➡",
      task_done = "",
      task_cancelled = "",
      task_info = "",
    },
  }

  local slang_conceal = function(chunks)
    if not lib.is.table(chunks) then return chunks end

    -- substituting here can remove initial flicker
    local substitutions = {
      -- heading
      -- ["\\v^\\s*\\zs\\*+\\ze"] = config.chars.heading,
      -- section
      -- ["\\v^\\s*\\zs\\>\\ze"] = config.chars.section_collapsed,
      -- list item
      -- ["\\v^\\s*\\zs\\-\\ze"] = config.chars.list_item,
      -- tasks
      -- ["\\v^\\s*\\zs\\[\\s\\]\\ze"] = config.chars.task_default,
      -- ["\\v^\\s*\\zs\\[\\-\\]\\ze"] = config.chars.task_active,
      -- ["\\v^\\s*\\zs\\[x\\]\\ze"] = config.chars.task_done,
      -- ["\\v^\\s*\\zs\\[_\\]\\ze"] = config.chars.task_cancelled,
      [config.chars.section_expanded] = config.chars.section_collapsed,
    }

    local has_changed = false
    for index, chunk in ipairs(chunks) do
      if not has_changed then
        local text, _ = unpack(chunk)
        local trimmed_text = string.trim(text)
        if trimmed_text ~= "" then
          local concealed_text = text
          for pattern, replacement in pairs(substitutions) do
            concealed_text = vim.fn.substitute(concealed_text, pattern, replacement, "")
          end
          if concealed_text ~= text then
            text = concealed_text
            chunks[index][1] = text
            has_changed = true
          end
        end
      end
    end

    return chunks
  end

  local get_range_meta = function(start_line, end_line)
    local parser = vim.treesitter.get_parser(0)
    local tree = parser:parse()[1]
    local root = tree:root()

    local result = {
      default_tasks = 0,
      active_tasks = 0,
      done_tasks = 0,
      total_time = 0,
    }

    local filter_in_range = function(nodes)
      local filtered = {}
      for _, node in ipairs(nodes) do
        local start_row, _, end_row, _ = node:range()
        if start_row >= start_line and end_row <= end_line then table.insert(filtered, node) end
      end
      return filtered
    end

    result.default_tasks = #filter_in_range(lib.ts.find_children(root, "task_default", true))
    result.active_tasks = #filter_in_range(lib.ts.find_children(root, "task_active", true))
    result.done_tasks = #filter_in_range(lib.ts.find_children(root, "task_done", true))

    local total_time = 0
    local sessions = filter_in_range(lib.ts.find_children(root, "task_session", true))
    for _, session in ipairs(sessions) do
      local datetimerange = lib.ts.find_child(session, "datetimerange", true)
      if datetimerange then
        local datetime_nodes = lib.ts.find_children(datetimerange, "datetime", true)

        local start_str = ""
        local end_str = ""

        -- case 1: (datetimerange (datetime date time) time)
        -- 2023.12.15 16:48-16:50
        if #datetime_nodes == 1 then
          local start_date_node = lib.ts.find_child(datetime_nodes[1], "date", true)
          local start_time_node = lib.ts.find_child(datetime_nodes[1], "time", true)
          local end_time_node = lib.ts.find_child(datetimerange, "time", false)

          if start_date_node and start_time_node and end_time_node then
            local start_date_str = vim.treesitter.get_node_text(start_date_node, 0)
            local start_time_str = vim.treesitter.get_node_text(start_time_node, 0)
            local end_time_str = vim.treesitter.get_node_text(end_time_node, 0)

            start_str = start_date_str .. " " .. start_time_str
            end_str = start_date_str .. " " .. end_time_str
          end
        end

        if start_str ~= "" and end_str ~= "" then
          local start_time = vim.fn.strptime("%Y.%m.%d %H:%M", start_str)
          local end_time = vim.fn.strptime("%Y.%m.%d %H:%M", end_str)
          local duration = end_time - start_time
          -- if duration == 0 then duration = 30 * 60 end
          total_time = total_time + duration
        end

        -- -- TODO: case 2: (datetimerange (datetime date time) (datetime date time))
        -- -- 2023.12.15 16:48 - 2023.12.15 16:50
        -- if #datetime_nodes == 2 then
        --   local start_date_node = lib.ts.find_child(datetime_nodes[1], "date", true)
        --   local start_time_node = lib.ts.find_child(datetime_nodes[1], "time", true)
        --   local end_date_node = lib.ts.find_child(datetime_nodes[2], "date", true)
        --   local end_time_node = lib.ts.find_child(datetime_nodes[2], "time", true)
        --
        --   local start_date_str = start_date_node and start_date_node:sexpr()
        --   local start_time_str = start_time_node and start_time_node:sexpr()
        --   local end_date_str = end_date_node and end_date_node:sexpr()
        --   local end_time_str = end_time_node and end_time_node:sexpr()
        --
        --   if start_date_str and start_time_str and end_date_str and end_time_str then
        --     local start_time = vim.fn.strptime(start_date_str .. " " .. start_time_str, "%Y.%m.%d %H:%M")
        --     local end_time = vim.fn.strptime(end_date_str .. " " .. end_time_str, "%Y.%m.%d %H:%M")
        --     total_time = total_time + (end_time - start_time)
        --   end
        -- end
      end
    end
    result.total_time = total_time

    return result
  end

  ---@diagnostic disable-next-line: unused-local
  local virtual_text_handler = function(originalVirtualTextChunks, start_line, end_line, width, truncate)
    if lib.buffer.current.get_filetype() == "syslang" then
      local virtualTextChunks = slang_conceal(originalVirtualTextChunks)
      -- local folded_lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, true)
      local folded_lines_count = end_line - start_line

      local max_length = 80
      local text_length = 0
      for _, chunk in ipairs(virtualTextChunks) do
        text_length = text_length + vim.fn.strdisplaywidth(chunk[1])
      end

      -- slang tasks
      local meta = nil
      local tasks_todo_count = 0
      local tasks_done_count = 0
      local tasks_total_count = 0

      if enable_slang_meta then
        meta = get_range_meta(start_line, end_line)
        tasks_todo_count = meta.default_tasks + meta.active_tasks
        tasks_done_count = meta.done_tasks
        tasks_total_count = meta.default_tasks + meta.active_tasks + meta.done_tasks
      else
        local normal_task_count = 0
        local active_task_count = 0
        local completed_task_count = 0
        local folded_lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, true)

        for _, current_line in ipairs(folded_lines) do
          local text = string.trim(current_line)
          if string.starts_with(text, "[ ]") then
            normal_task_count = normal_task_count + 1
          elseif string.starts_with(text, "[x]") then
            completed_task_count = completed_task_count + 1
          elseif string.starts_with(text, "[-]") then
            active_task_count = active_task_count + 1
          end
        end

        tasks_todo_count = normal_task_count + active_task_count
        tasks_done_count = completed_task_count
        tasks_total_count = normal_task_count + active_task_count + completed_task_count
      end

      -- change highlight if all the children tasks are done
      local hlmap = {
        ["@slang.outline_1.marker.syslang"] = "@slang.outline_done",
        ["@slang.outline_1.text.syslang"] = "@slang.outline_done",
        ["@slang.outline_2.marker.syslang"] = "@slang.outline_done",
        ["@slang.outline_2.text.syslang"] = "@slang.outline_done",
        ["@slang.outline_3.marker.syslang"] = "@slang.outline_done",
        ["@slang.outline_3.text.syslang"] = "@slang.outline_done",
        ["@slang.outline_4.marker.syslang"] = "@slang.outline_done",
        ["@slang.outline_4.text.syslang"] = "@slang.outline_done",
        ["@slang.outline_5.marker.syslang"] = "@slang.outline_done",
        ["@slang.outline_5.text.syslang"] = "@slang.outline_done",
        ["@slang.outline_6.marker.syslang"] = "@slang.outline_done",
        ["@slang.outline_6.text.syslang"] = "@slang.outline_done",
      }
      if tasks_todo_count == 0 and tasks_done_count > 0 then
        for index, chunk in ipairs(virtualTextChunks) do
          local group = vim.fn.synIDattr(chunk[2], "name")
          if hlmap[group] then virtualTextChunks[index][2] = hlmap[group] end
        end
      end

      -- compute task info
      local tasks_info = ""
      if tasks_total_count > 0 then
        if tasks_todo_count == 0 then
          tasks_info = string.format("%s %s/%s", config.chars.task_info, tasks_done_count, tasks_total_count)
        else
          tasks_info = string.format("%s %s/%s", config.chars.task_info, tasks_done_count, tasks_total_count)
        end
      end

      -- meta
      if meta and meta.total_time > 0 then
        local format_time = function(seconds)
          local hours = math.floor(seconds / 3600)
          local minutes = math.floor((seconds % 3600) / 60)
          local time = ""
          if hours > 0 then time = time .. string.format("%dh", hours) end
          if minutes > 0 then time = time .. string.format("%dm", minutes) end
          return time
        end
        tasks_info = tasks_info .. string.format("  %s", format_time(meta.total_time))
      end

      -- padding
      local info_without_padding = " " .. tasks_info .. string.format(" %d lines", folded_lines_count)
      local padding_length = max_length - #info_without_padding - text_length
      local padding = ""
      if padding_length > 0 then padding = string.rep(" ", padding_length) end

      -- render prefix and task info
      table.insert(virtualTextChunks, { config.folded_info_prefix, "Comment" })
      if tasks_todo_count > 0 then
        table.insert(virtualTextChunks, { tasks_info, "@slang.ticket" })
      else
        table.insert(virtualTextChunks, { tasks_info, "@slang.task_done" })
      end

      -- render suffing
      local padding_suffix = ""
      if config.show_folded_line_count then padding_suffix = string.format(" %d lines", folded_lines_count) end
      table.insert(virtualTextChunks, { padding .. padding_suffix, "NonText" })

      return virtualTextChunks
    end

    -- default
    local newVirtText = {}
    local suffix = (" 󰁂 %d "):format(end_line - start_line)
    local sufWidth = vim.fn.strdisplaywidth(suffix)
    local targetWidth = width - sufWidth
    local curWidth = 0
    for _, chunk in ipairs(originalVirtualTextChunks) do
      local chunkText = chunk[1]
      local chunkWidth = vim.fn.strdisplaywidth(chunkText)
      if targetWidth > curWidth + chunkWidth then
        table.insert(newVirtText, chunk)
      else
        chunkText = truncate(chunkText, targetWidth - curWidth)
        local hlGroup = chunk[2]
        table.insert(newVirtText, { chunkText, hlGroup })
        chunkWidth = vim.fn.strdisplaywidth(chunkText)
        if curWidth + chunkWidth < targetWidth then
          suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
        end
        break
      end
      curWidth = curWidth + chunkWidth
    end
    table.insert(newVirtText, { suffix, "MoreMsg" })
    return newVirtText
  end

  -- ufo
  local ufo = require("ufo")
  ufo.setup({
    open_fold_hl_timeout = 0,
    fold_virt_text_handler = virtual_text_handler,
    provider_selector = function(_, filetype)
      if filetype == "syslang" then return { "treesitter" } end
      return ""
    end,
    close_fold_kinds_for_ft = {
      syslang = { "document_meta", "task_done", "section" },
    },
  })

  local open_all_folds = function()
    -- vim.opt_local.foldlevel = 999
    local c = require("ufo.config")
    log(c)
    require("ufo.action").openFoldsExceptKinds(
      c.close_fold_kinds_for_ft[vim.bo.ft] or c.close_fold_kinds_for_ft.default
    )
  end

  local close_all_folds = function()
    -- vim.schedule(function()
    --   local timer = vim.loop.new_timer()
    --   timer:start(
    --     0,
    --     10,
    --     vim.schedule_wrap(function()
    --       timer:stop()
    --       for i = 10 .. 0, -1, -1 do
    --         ufo.closeFoldsWith(i)
    --       end
    --     end)
    --   )
    -- end)
    vim.cmd("UfoDisableFold")

    require("modules/workflow/reset-view").exports.reset_folds(true)
    require("fold-cycle").close_all()
    ufo.closeAllFolds()
  end

  -- https://github.com/kevinhwang91/nvim-ufo/blob/main/doc/example.lua#L113
  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufWritePost", "TextChanged" }, {
    callback = function()
      local ft = vim.bo.filetype
      if ft ~= "syslang" then return end
      require("async")(function()
        local bufnr = vim.api.nvim_get_current_buf()
        if not require("ufo").hasAttached(bufnr) then return end
        -- require("ufo").attach(bufnr)
        local _, getfolds = pcall(require("ufo").getFolds, bufnr, "treesitter")
        local ok, ranges = pcall(await, getfolds)
        if ok and ranges then
          ok = pcall(require("ufo").applyFolds, bufnr, ranges)
          -- if ok then require("ufo").closeAllFolds() end
        end
      end)
    end,
  })

  vim.keymap.set("n", "zR", open_all_folds, { desc = "Open all folds" })
  vim.keymap.set("n", "zM", close_all_folds, { desc = "Close all folds" })
end

local setup_fold_cycle = function()
  require("fold-cycle").setup({
    open_if_max_closed = true,
    close_if_max_opened = true,
    softwrap_movement_fix = false,
  })

  -- <tab> - open / cycle
  vim.keymap.set("n", "<tab>", function()
    require("fold-cycle").open()
  end, { silent = true, desc = "Fold-cycle: open folds" })

  -- <s-tab> - collapse
  vim.keymap.set("n", "<s-tab>", function()
    local filetype = vim.bo.filetype

    -- slang: move to fold start
    if filetype == "syslang" then
      local is_open_fold_child = is_current_line_in_open_fold_and_is_not_first()
      if is_open_fold_child then vim.api.nvim_exec2("normal! [z", {}) end
    end

    require("fold-cycle").close_all()
  end, { silent = true, noremap = true })
end

-- https://nanotipsforvim.prose.sh/better-folding-%28part-1%29--pause-folds-while-searching
local setup = function()
  vim.opt.foldopen:remove({ "search" }) -- no auto-open when searching, since the following snippet does that better

  vim.keymap.set("n", "/", "zn/", { desc = "Search & Pause Folds" })
  vim.on_key(function(char)
    local key = vim.fn.keytrans(char)
    local searchKeys = { "n", "N", "*", "#", "/", "?" }
    local searchConfirmed = (key == "<CR>" and vim.fn.getcmdtype():find("[/?]") ~= nil)
    if not (searchConfirmed or vim.fn.mode() == "n") then return end
    local searchKeyUsed = searchConfirmed or (vim.tbl_contains(searchKeys, key))

    local pauseFold = vim.opt.foldenable:get() and searchKeyUsed
    local unpauseFold = not (vim.opt.foldenable:get()) and not searchKeyUsed
    if pauseFold then
      vim.opt.foldenable = false
    elseif unpauseFold then
      vim.opt.foldenable = true
      vim.cmd.normal("zv") -- after closing folds, keep the *current* fold open
    end
  end, vim.api.nvim_create_namespace("auto_pause_folds"))
end

return lib.module.create({
  name = "workflow/folds",
  hosts = "*",
  setup = setup,
  plugins = {
    {
      "kevinhwang91/nvim-ufo",
      -- "3rd/nvim-ufo",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "nvim-ufo"),
      ft = "syslang",
      dependencies = { "nvim-treesitter", "kevinhwang91/promise-async" },
      config = setup_ufo,
    },
    {
      "jghauser/fold-cycle.nvim",
      -- "3rd/fold-cycle.nvim",
      -- dir = lib.path.resolve(lib.env.dirs.vim.config, "plugins", "fold-cycle.nvim"),
      ft = { "syslang" },
      config = setup_fold_cycle,
    },
  },
})

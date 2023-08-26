local get_upper_fold_level = function()
  local winview = vim.fn.winsaveview()
  local foldlevel = -1
  local ok = pcall(vim.cmd, "keepjumps normal! [z")
  if ok then foldlevel = vim.fn.foldlevel(vim.fn.line(".")) end
  vim.fn.winrestview(winview)
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
    -- folded_info_prefix = "... ",
    folded_info_prefix = "…  ",
    show_folded_line_count = false,
    chars = {
      heading = "◉",
      section_collapsed = "⮞",
      section_expanded = "⮟",
      list_item = "•",
      task_default = "",
      task_active = "➡",
      task_done = "",
      task_cancelled = "",
      task_info = "☑",
    },
  }

  local slang_conceal = function(chunks)
    if not lib.is.table(chunks) then return chunks end
    local substitutions = {
      -- heading
      ["\\v^\\s*\\zs\\*+\\ze"] = config.chars.heading,
      -- section
      ["\\v^\\s*\\zs\\>\\ze"] = config.chars.section_collapsed,
      -- list item
      ["\\v^\\s*\\zs\\-\\ze"] = config.chars.list_item,
      -- tasks
      ["\\v^\\s*\\zs\\[\\s\\]\\ze"] = config.chars.task_default,
      ["\\v^\\s*\\zs\\[\\-\\]\\ze"] = config.chars.task_active,
      ["\\v^\\s*\\zs\\[x\\]\\ze"] = config.chars.task_done,
      ["\\v^\\s*\\zs\\[_\\]\\ze"] = config.chars.task_cancelled,
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

  ---@diagnostic disable-next-line: unused-local
  local handler = function(originalVirtualTextChunks, start_line, end_line, width, truncate)
    if lib.buffer.current.get_filetype() == "syslang" then
      local virtualTextChunks = slang_conceal(originalVirtualTextChunks)
      local folded_lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, true)
      local folded_lines_count = end_line - start_line

      local max_length = 80
      local text_length = 0
      for _, chunk in ipairs(virtualTextChunks) do
        text_length = text_length + vim.fn.strdisplaywidth(chunk[1])
      end

      -- slang tasks
      local normal_task_count = 0
      local active_task_count = 0
      local completed_task_count = 0
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
      local tasks_todo_count = normal_task_count + active_task_count
      local tasks_done_count = completed_task_count
      local tasks_total_count = normal_task_count + active_task_count + completed_task_count

      -- change highlight if all the children tasks are done
      local hlmap = {
        ["@slang.heading_1.marker.syslang"] = "@slang.heading_done",
        ["@slang.heading_1.text.syslang"] = "@slang.heading_done",
        ["@slang.heading_2.marker.syslang"] = "@slang.heading_done",
        ["@slang.heading_2.text.syslang"] = "@slang.heading_done",
        ["@slang.heading_3.marker.syslang"] = "@slang.heading_done",
        ["@slang.heading_3.text.syslang"] = "@slang.heading_done",
        ["@slang.heading_4.marker.syslang"] = "@slang.heading_done",
        ["@slang.heading_4.text.syslang"] = "@slang.heading_done",
        ["@slang.heading_5.marker.syslang"] = "@slang.heading_done",
        ["@slang.heading_5.text.syslang"] = "@slang.heading_done",
        ["@slang.heading_6.marker.syslang"] = "@slang.heading_done",
        ["@slang.heading_6.text.syslang"] = "@slang.heading_done",
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

  local ufo = require("ufo")

  ufo.setup({
    open_fold_hl_timeout = 0,
    fold_virt_text_handler = handler,
    provider_selector = function(bufnr, filetype, buftype)
      return { "treesitter" }
    end,
  })

  local open_all_folds = function()
    vim.opt_local.foldlevel = 999
    ufo.openAllFolds()
  end

  local close_all_folds = function()
    vim.opt_local.foldlevel = 999
    -- ufo.closeAllFolds()
    ufo.closeFoldsWith(0)
  end

  vim.keymap.set("n", "zR", open_all_folds, { desc = "Open all folds" })
  vim.keymap.set("n", "zM", close_all_folds, { desc = "Close all folds" })
end

local setup = function()
  vim.keymap.set("n", "<tab>", "za")
  vim.keymap.set("n", "<s-tab>", function()
    local filetype = vim.bo.filetype
    if filetype == "syslang" then
      local is_open_fold_child = is_current_line_in_open_fold_and_is_not_first()
      if is_open_fold_child then vim.api.nvim_exec2("normal! [z", {}) end
    end
    pcall(vim.api.nvim_exec2, "normal! zc", {})
  end, { silent = true, noremap = true })
end

local setup_fold_cycle = function()
  require("fold-cycle").setup({
    open_if_max_closed = true,
    close_if_max_opened = true,
    softwrap_movement_fix = true,
  })

  -- <tab> - open / cycle
  vim.keymap.set("n", "<tab>", function()
    require("fold-cycle").open()
    -- https://github.com/lukas-reineke/indent-blankline.nvim/issues/449
    -- vim.cmd("IndentBlanklineRefresh")
  end, { silent = true, desc = "Fold-cycle: open folds" })

  -- <s-tab> - collapse
  vim.keymap.set("n", "<s-tab>", function()
    -- return require("fold-cycle").close()
    local filetype = vim.bo.filetype
    if filetype == "syslang" then
      local is_open_fold_child = is_current_line_in_open_fold_and_is_not_first()
      if is_open_fold_child then vim.api.nvim_exec2("normal! [z", {}) end
    end
    pcall(vim.api.nvim_exec2, "normal! zc", {})
  end, { silent = true, noremap = true })

  -- vim.keymap.set("n", "zC", function()
  --   return require("fold-cycle").close_all()
  -- end, { remap = true, silent = true, desc = "Fold-cycle: close all folds" })
end

return lib.module.create({
  name = "workflow/folds",
  setup = setup,
  plugins = {
    {
      "kevinhwang91/nvim-ufo",
      event = "VimEnter",
      dependencies = { "nvim-treesitter", "kevinhwang91/promise-async" },
      config = setup_ufo,
    },
    {
      "jghauser/fold-cycle.nvim",
      ft = { "syslang" },
      config = setup_fold_cycle,
    },
  },
  hooks = {
    lsp = {
      capabilities = function(capabilities)
        return vim.tbl_deep_extend("force", capabilities or {}, {
          textDocument = {
            foldingRange = {
              dynamicRegistration = false,
              lineFoldingOnly = true,
            },
          },
        })
      end,
    },
  },
})

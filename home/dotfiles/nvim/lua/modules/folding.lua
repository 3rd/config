local setup_ufo = function()
  local lib = require("lib")

  local slang_conceal = function(chunks)
    if not lib.is.table(chunks) then
      return chunks
    end
    for index, chunk in ipairs(chunks) do
      local text, _hid = unpack(chunk)
      local trimmed_text = lib.string.trim(text)
      if not trimmed_text ~= "" then
        local next_chunk = chunks[index + 1]
        local next_chunk_text_begins_with_space = next_chunk and next_chunk[1]:sub(1, 1) == " "
        local concealed_text = text
        if next_chunk_text_begins_with_space then
          concealed_text = vim.fn.substitute(text, [[\v^\s*\zs\*+\ze]], "◉", "")
          concealed_text = vim.fn.substitute(concealed_text, [[\v^\s*\zs\>\ze]], "⮞", "")
        end
        concealed_text = vim.fn.substitute(concealed_text, [[\v^\s*\zs\[\s\]\ze]], "▢", "")
        concealed_text = vim.fn.substitute(concealed_text, [[\v^\s*\zs\[-\]\ze]], "🞆", "")
        concealed_text = vim.fn.substitute(concealed_text, [[\v^\s*\zs\[x\]\ze]], "✔", "")
        if concealed_text ~= text then
          text = concealed_text
          chunks[index][1] = text
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
        local text = lib.string.trim(current_line)
        if lib.string.starts_with(text, "[ ]") then
          normal_task_count = normal_task_count + 1
        elseif lib.string.starts_with(text, "[x]") then
          completed_task_count = completed_task_count + 1
        elseif lib.string.starts_with(text, "[-]") then
          active_task_count = active_task_count + 1
        end
      end
      local tasks_todo_count = normal_task_count + active_task_count
      local tasks_done_count = completed_task_count
      local tasks_total_count = normal_task_count + active_task_count + completed_task_count
      local tasks_info = ""

      if tasks_total_count > 0 then
        if tasks_todo_count == 0 then
          tasks_info = string.format("✔ %s/%s", tasks_done_count, tasks_total_count)
        else
          tasks_info = string.format("%s/%s", tasks_done_count, tasks_total_count)
        end
      end

      local info_without_padding = " " .. tasks_info .. string.format(" %d lines", folded_lines_count)
      local padding_length = max_length - #info_without_padding - text_length
      local padding = ""
      if padding_length > 0 then
        padding = string.rep(".", padding_length)
      end

      -- " " .. task completion status .. padding .. " " .. line count
      table.insert(virtualTextChunks, { " ", "NonText" })
      if tasks_todo_count > 0 then
        table.insert(virtualTextChunks, { tasks_info, "WarningMsg" })
      else
        table.insert(virtualTextChunks, { tasks_info, "NonText" })
      end
      table.insert(virtualTextChunks, { padding .. string.format(" %d lines", folded_lines_count), "NonText" })

      return virtualTextChunks
    else
      local newVirtText = {}
      local suffix = ("  %d "):format(end_line - start_line)
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
  end

  local ufo = require("ufo")

  ufo.setup({
    open_fold_hl_timeout = 0,
    fold_virt_text_handler = handler,
    provider_selector = function(bufnr, filetype, buftype)
      -- return ""
      return { "treesitter" }
    end,
  })

  vim.keymap.set("n", "zR", function()
    vim.opt.foldlevel = 999
    ufo.openAllFolds()
    -- vim.cmd("w")
  end)
  vim.keymap.set("n", "zM", function()
    vim.opt.foldlevel = 999
    ufo.closeAllFolds()
  end)
end

return require("lib").module.create({
  enabled = true,
  name = "folding",
  plugins = {
    {
      "kevinhwang91/nvim-ufo",
      requires = { "kevinhwang91/promise-async" },
      after = { "nvim-treesitter" },
      config = setup_ufo,
    },
  },
})

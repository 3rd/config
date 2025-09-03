local CHAT_ENDPOINT = "https://api.anthropic.com/v1/messages"
local API_KEY = os.getenv("ANTHROPIC_API_KEY")

---@class LLMModel
---@field id string
---@field name string
---@field description string

---@class LLMOptions
---@field model? string
---@field max_tokens? number
---@field thinking? table

---@class LLMMessage
---@field role string
---@field content string

-- model configuration
local models = {
  sonnet = {
    id = "claude-sonnet-4-20250514",
    name = "Claude Sonnet 4",
    description = "Speedy",
  },
  opus = {
    id = "claude-opus-4-20250514",
    name = "Claude Opus 4",
    description = "Big boss",
  },
}

-- state
local state = {
  current_model = "sonnet",
  thinking_budget = 10000,
}

local function get_current_model()
  return models[state.current_model]
end

local function switch_model()
  if state.current_model == "sonnet" then
    state.current_model = "opus"
  else
    state.current_model = "sonnet"
  end
  local model = get_current_model()
  vim.notify(string.format("Switched to %s - %s", model.name, model.description), vim.log.levels.INFO)
end

local function setup_cancel_autocmd(buf)
  local group = "LLMBufferChange_" .. buf
  vim.api.nvim_create_augroup(group, { clear = true })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    buffer = buf,
    callback = function()
      if vim.b.llm_job_id then
        local current = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
        if current ~= vim.b.llm_original_text then
          vim.ui.input({
            prompt = "Buffer modified while LLM request is in progress. Cancel request? (y/n): ",
          }, function(input)
            if input and input:lower() == "y" then
              vim.fn.jobstop(vim.b.llm_job_id)
              vim.b.llm_job_id = nil
              vim.notify("LLM request canceled", vim.log.levels.INFO)
              vim.api.nvim_clear_autocmds({ group = group, buffer = buf })
            else
              local orig_lines = vim.split(vim.b.llm_original_text, "\n")
              vim.api.nvim_buf_set_lines(buf, 0, -1, false, orig_lines)
              vim.notify("Changes reverted. LLM request continues.", vim.log.levels.INFO)
            end
          end)
        end
      end
    end,
  })
end

---@param prompt string
---@param options? LLMOptions
---@param callback fun(result:string|nil)
---@param streaming_popup? table Optional popup for streaming updates
local async_complete = function(prompt, options, callback, streaming_popup)
  if not API_KEY or API_KEY == "" then
    vim.schedule(function()
      vim.notify("Error: ANTHROPIC_API_KEY is not set", vim.log.levels.ERROR)
      callback(nil)
    end)
    return
  end

  local current_model = get_current_model()
  local messages = {
    { role = "user", content = prompt },
  }

  local opts = vim.tbl_deep_extend("force", {
    model = current_model.id,
    max_tokens = 32000,
    thinking = {
      type = "enabled",
      budget_tokens = state.thinking_budget,
    },
    stream = streaming_popup and true or false,
  }, options or {})

  local payload = vim.tbl_deep_extend("force", opts, {
    messages = messages,
  })

  local tmpfile = vim.fn.tempname()
  lib.fs.file.write(tmpfile, vim.fn.json_encode(payload))

  local command = string.format(
    "curl -s -X POST -H 'Content-Type: application/json' -H 'x-api-key: %s' -H 'anthropic-version: 2023-06-01' -d '@%s' %s",
    API_KEY,
    tmpfile,
    CHAT_ENDPOINT
  )

  -- loading popup with model info
  local columns = vim.o.columns
  local model_info = string.format("%s", current_model.name)
  local loading_popup = require("nui.popup")({
    position = { row = 1, col = columns - string.len(model_info) - 10 },
    size = { width = string.len(model_info) + 8, height = 1 },
    enter = false,
    win_options = { winblend = 10 },
  })
  loading_popup:mount()

  -- close with q
  vim.keymap.set("n", "q", function()
    loading_popup:unmount()
  end, { buffer = loading_popup.bufnr, silent = true })
  vim.api.nvim_buf_set_lines(loading_popup.bufnr, 0, -1, false, { model_info .. "..." })

  if streaming_popup then
    -- streaming mode
    local content_blocks = {}
    local current_event = nil
    local json_buffer = ""

    local job_id = vim.fn.jobstart(command, {
      stdout_buffered = false,
      on_stdout = function(_job_id, data, _event)
        if data then
          for _, chunk in ipairs(data) do
            if chunk ~= "" then
              -- each chunk is either an event: line or data: line
              if chunk:match("^event:") then
                current_event = chunk:match("^event:%s*(.+)")
                json_buffer = "" -- clear on new event
              elseif chunk:match("^data:") then
                local data_json = chunk:match("^data:%s*(.+)")

                if data_json then
                  json_buffer = json_buffer .. data_json

                  local status, event_data = pcall(vim.fn.json_decode, json_buffer)
                  if status and event_data then
                    json_buffer = ""

                    vim.schedule(function()
                      if event_data.type == "content_block_start" then
                        content_blocks[event_data.index] = {
                          type = event_data.content_block.type,
                          content = "",
                        }
                      elseif event_data.type == "content_block_delta" and event_data.delta then
                        local index = event_data.index
                        if content_blocks[index] then
                          local delta_text = ""
                          if event_data.delta.type == "thinking_delta" and event_data.delta.thinking then
                            delta_text = event_data.delta.thinking
                          elseif event_data.delta.type == "text_delta" and event_data.delta.text then
                            delta_text = event_data.delta.text
                          elseif event_data.delta.type == "signature_delta" then
                            return
                          end

                          -- append text delta
                          content_blocks[index].content = content_blocks[index].content .. delta_text

                          -- build display content
                          local display_content = ""
                          local thinking_content = ""
                          local text_content = ""

                          -- collect all content blocks by type
                          for block_index, block in pairs(content_blocks) do
                            if block and block.content ~= "" then
                              if block.type == "thinking" then
                                thinking_content = thinking_content .. block.content
                              elseif block.type == "text" then
                                text_content = text_content .. block.content
                              end
                            end
                          end

                          -- build display with sections and divider
                          if thinking_content ~= "" then
                            display_content = display_content .. "🤔 **Thinking:**\n" .. thinking_content .. "\n\n"
                          end

                          if thinking_content ~= "" and text_content ~= "" then
                            display_content = display_content .. "---\n\n"
                          end

                          if text_content ~= "" then
                            display_content = display_content .. "💬 **Response:**\n" .. text_content .. "\n\n"
                          end

                          streaming_popup.update_content(display_content)
                        else
                        end
                      else
                      end
                    end)
                  else
                    -- JSON parse failed, keep in buffer for next chunk
                    if #json_buffer > 10000 then
                      log("Large unparsed JSON buffer: " .. string.sub(json_buffer, 1, 100) .. "...")
                      json_buffer = "" -- reset to prevent memory issues
                    end
                  end
                end
              end
            end
          end
        end
      end,
      on_stderr = function(_job_id, data, _event)
        if data then
          for _, line in ipairs(data) do
            if line and line ~= "" then
              vim.schedule(function()
                vim.api.nvim_err_writeln(line)
              end)
            end
          end
        end
      end,
      on_exit = function(_job_id, _exit_code, _event)
        vim.schedule(function()
          vim.b.llm_job_id = nil

          -- find final text content (not thinking)
          local text_content = ""
          for block_index, block in pairs(content_blocks) do
            if block and block.type == "text" then text_content = text_content .. block.content end
          end

          if text_content == "" then
            vim.notify("Error: No text content received", vim.log.levels.ERROR)
            callback(nil)
          else
            callback(vim.fn.trim(text_content, "\n"))
          end

          -- only unmount loading popup after streaming is complete
          loading_popup:unmount()
        end)
      end,
    })
  else
    -- non-streaming mode (original implementation)
    local output_lines = {}
    local job_id = vim.fn.jobstart(command, {
      stdout_buffered = true,
      on_stdout = function(_job_id, data, _event)
        if data then
          for _, line in ipairs(data) do
            if line ~= "" then table.insert(output_lines, line) end
          end
        end
      end,
      on_stderr = function(_job_id, data, _event)
        if data then
          for _, line in ipairs(data) do
            if line and line ~= "" then
              vim.schedule(function()
                vim.api.nvim_err_writeln(line)
              end)
            end
          end
        end
      end,
      on_exit = function(_job_id, _exit_code, _event)
        loading_popup:unmount()
        vim.schedule(function()
          vim.b.llm_job_id = nil
        end)
        local output = table.concat(output_lines, "\n")
        local status, response = pcall(vim.fn.json_decode, output)
        if not status then
          vim.schedule(function()
            vim.notify("Error: Failed to decode LLM response: " .. output, vim.log.levels.ERROR)
            callback(nil)
          end)
          return
        end

        if response.error then
          vim.schedule(function()
            vim.notify("Error: " .. vim.inspect(response.error), vim.log.levels.ERROR)
            callback(nil)
          end)
          return
        end

        if not (response and response.content) then
          vim.schedule(function()
            vim.notify(
              "Error: Unexpected LLM response format. Response: " .. vim.inspect(response),
              vim.log.levels.ERROR
            )
            callback(nil)
          end)
          return
        end

        -- find the text content block (with thinking enabled, there are multiple content blocks)
        local text_content = nil
        for _, content_block in ipairs(response.content) do
          if content_block.type == "text" and content_block.text then
            text_content = content_block.text
            break
          end
        end

        if not text_content then
          vim.schedule(function()
            vim.notify("Error: No text content found in response", vim.log.levels.ERROR)
            callback(nil)
          end)
          return
        end

        local result = vim.fn.trim(text_content, "\n")
        vim.schedule(function()
          callback(result)
        end)
      end,
    })
  end

  vim.b.llm_job_id = job_id

  -- clean up temp file
  vim.defer_fn(function()
    pcall(vim.fn.delete, tmpfile)
  end, 1000)
end

---@param prompt string
---@param options? LLMOptions
---@param callback fun(result:string|nil)
local complete = function(prompt, options, callback)
  async_complete(prompt, options, callback)
end

---create a result popup window with content
---@param content string
---@param filetype? string
local function create_result_popup(content, filetype)
  local event = require("nui.utils.autocmd").event
  local popup = require("nui.popup")({
    enter = true,
    focusable = true,
    position = "50%",
    size = { width = "80%", height = "60%" },
    win_options = { wrap = true },
  })

  popup:mount()

  -- close with q
  vim.keymap.set("n", "q", function()
    popup:unmount()
  end, { buffer = popup.bufnr, silent = true })

  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  local lines = vim.split(content, "\n", {})
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(popup.bufnr, "ft", filetype or "markdown")

  popup:on(event.BufEnter, function()
    vim.cmd("normal! gg")
  end)

  return popup
end

---create a streaming popup window that updates in real-time
---@param title? string
local function create_streaming_popup(title)
  local event = require("nui.utils.autocmd").event
  local popup = require("nui.popup")({
    enter = true,
    focusable = true,
    position = "50%",
    size = { width = "80%", height = "60%" },
    border = {
      style = "rounded",
      text = {
        top = title or "Streaming response...",
        top_align = "left",
      },
    },
    win_options = { wrap = true },
  })

  popup:mount()

  -- close with q
  vim.keymap.set("n", "q", function()
    popup:unmount()
  end, { buffer = popup.bufnr, silent = true })

  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  -- set initial empty content and markdown filetype
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, { "" })
  vim.api.nvim_buf_set_option(popup.bufnr, "ft", "markdown")

  -- utility function to update popup content
  popup.update_content = function(content)
    local lines = vim.split(content, "\n", {})
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)

    -- auto-scroll to bottom and center last line
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(popup.winid) then
        vim.api.nvim_set_current_win(popup.winid)
        vim.cmd("normal! G") -- go to last line
        vim.cmd("normal! zz") -- center the line
      end
    end)
  end

  -- utility function to append content
  popup.append_content = function(new_text)
    local current_lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
    local current_content = table.concat(current_lines, "\n")
    local updated_content = current_content .. new_text
    local lines = vim.split(updated_content, "\n", {})
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)

    -- auto-scroll to bottom and center last line
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(popup.winid) then
        vim.api.nvim_set_current_win(popup.winid)
        vim.cmd("normal! G") -- go to last line
        vim.cmd("normal! zz") -- center the line
      end
    end)
  end

  popup:on(event.BufEnter, function()
    vim.cmd("normal! G") -- go to bottom when entering
  end)

  return popup
end

---streaming version that shows response in real-time
---@param prompt string
---@param options? LLMOptions
---@param callback fun(result:string|nil)
local complete_streaming = function(prompt, options, callback)
  local current_model = get_current_model()
  local streaming_popup = create_streaming_popup(current_model.name .. " - Streaming...")

  async_complete(prompt, options, function(result)
    -- when streaming is complete, close streaming popup and show final result
    streaming_popup:unmount()
    if result then create_result_popup(result, "markdown") end
    callback(result)
  end, streaming_popup)
end

---explain the given code.
---@param code string
local explain = function(code)
  local filename = vim.fn.expand("%:t")
  local filetype = vim.bo.filetype
  local prompt = vim.fn.join({
    "Explain what the following code does.",
    "Filename: " .. filename,
    "Content:\n```" .. filetype .. "\n" .. code .. "\n```",
    "Explanation:",
  }, "\n")
  complete_streaming(prompt, nil, function(result) end)
end

-- enhanced input with model switching - using fallback approach if nui.input has issues
local function create_enhanced_input(prompt_text, callback)
  local function get_prompt_with_model()
    local model = get_current_model()
    return string.format(
      "%s [%s - budget:%dk - ESC then <C-n>:switch <C-b>:budget q:close]: ",
      prompt_text,
      model.name,
      math.floor(state.thinking_budget / 1000)
    )
  end

  -- Use nui.input with proper BufEnter handling
  local use_nui = true

  if use_nui then
    local Input = require("nui.input")
    local event = require("nui.utils.autocmd").event

    local input = Input({
      position = "50%",
      size = { width = math.min(60, vim.o.columns - 4) },
      border = {
        style = "rounded",
        text = {
          top = get_prompt_with_model(),
          top_align = "left",
        },
      },
      win_options = {
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
      },
    }, {
      prompt = "> ",
      default_value = "",
      on_close = function() end,
      on_submit = function(value)
        if value and value ~= "" then callback(value) end
      end,
    })

    -- add model switching keybind (normal mode)
    input:map("n", "<C-n>", function()
      switch_model()
      local new_prompt = get_prompt_with_model()
      input.border:set_text("top", new_prompt, "left")
    end, { noremap = true })

    -- add thinking budget adjustment keybind (normal mode)
    input:map("n", "<C-b>", function()
      vim.ui.input({
        prompt = string.format("Thinking budget (current: %d, min: 1024): ", state.thinking_budget),
        default = tostring(state.thinking_budget),
      }, function(budget_input)
        if budget_input then
          local budget = tonumber(budget_input)
          if budget and budget >= 1024 then
            state.thinking_budget = budget
            local new_prompt = get_prompt_with_model()
            input.border:set_text("top", new_prompt, "left")
            vim.notify(string.format("Thinking budget set to %d tokens", budget), vim.log.levels.INFO)
          else
            vim.notify("Invalid budget. Must be >= 1024", vim.log.levels.ERROR)
          end
        end
      end)
    end, { noremap = true })

    -- add close keybind (normal mode)
    input:map("n", "q", function()
      input:unmount()
    end, { noremap = true })

    input:on(event.BufLeave, function()
      input:unmount()
    end)

    input:on(event.BufEnter, function()
      vim.cmd("startinsert")
    end)

    input:mount()
  else
    -- Use vim.ui.input which actually works and enters insert mode
    vim.ui.input({
      prompt = get_prompt_with_model(),
      default = "",
    }, function(value)
      if value and value ~= "" then callback(value) end
    end)

    -- Show helpful message about model switching
    vim.notify(
      string.format(
        "Current: %s (budget: %dk). Use 'LLM: Switch model' or 'LLM: Set thinking budget' to change.",
        get_current_model().name,
        math.floor(state.thinking_budget / 1000)
      ),
      vim.log.levels.INFO
    )
  end
end

---ask a question about the given code.
---@param code string
local ask = function(code)
  local filetype = vim.bo.filetype
  create_enhanced_input("Ask", function(input)
    if not input then return end
    local prompt = "```" .. filetype .. "\n" .. code .. "\n```\n\n" .. input
    complete_streaming(prompt, nil, function(result)
      -- streaming popup already handled in complete_streaming
    end)
  end)
end

---edit code based on the provided instructions.
---@param code string
---@param instructions string
---@param callback fun(result:string|nil)
local edit = function(code, instructions, callback)
  local filetype = vim.bo.filetype
  local filename = vim.fn.expand("%:t")
  local prompt = table.concat({
    "Language: " .. filetype,
    "Filename: " .. filename,
    "Initial code:\n```" .. filetype .. "\n" .. code .. "\n```",
    "Instructions: " .. instructions,
    "Return a single markdown code block with the updated code, in such a way that it can replace the previous content.",
  }, "\n")
  complete_streaming(prompt, nil, function(result)
    if result then
      local start_idx, end_idx = string.find(result, "```[%w-]*\n(.-)```")
      if start_idx and end_idx then
        local code_block = string.match(result, "```[%w-]*\n(.-)```")
        result = vim.fn.trim(code_block, "\n")
      end
    end
    callback(result)
  end)
end

return lib.module.create({
  name = "llm",
  hosts = "*",
  actions = {
    {
      "n",
      "LLM: Generate code",
      function()
        create_enhanced_input("Prompt", function(input)
          local buf = vim.api.nvim_get_current_buf()
          vim.b.llm_original_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
          setup_cancel_autocmd(buf)
          local filename = vim.fn.expand("%:t")
          local filetype = vim.bo.filetype
          local prompt = vim.fn.join({
            "Language: " .. filetype,
            "Filename: " .. filename,
            "Instructions: " .. input,
          }, "\n")
          complete_streaming(prompt, nil, function(result)
            if result then
              local lines = vim.split(result, "\n", {})
              vim.api.nvim_put(lines, "l", true, true)
            end
          end)
        end)
      end,
    },
    {
      "v",
      "LLM: Explain code",
      function()
        local code = lib.buffer.current.get_selected_text()
        explain(code)
      end,
    },
    {
      "v",
      "LLM: Ask",
      function()
        local code = lib.buffer.current.get_selected_text()
        ask(code)
      end,
    },
    {
      "v",
      "LLM: Edit code",
      function()
        local buf = vim.api.nvim_get_current_buf()
        local start_line = vim.fn.getpos("'<")[2] - 1
        local end_line = vim.fn.getpos("'>")[2]
        local content = lib.buffer.current.get_selected_text()
        create_enhanced_input("Edit", function(change_prompt)
          vim.b.llm_original_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
          setup_cancel_autocmd(buf)
          edit(content, change_prompt, function(result)
            if result then
              local lines = vim.split(result, "\n", {})
              vim.api.nvim_buf_set_lines(buf, start_line, end_line, false, lines)
            end
          end)
        end)
      end,
    },
    {
      "n",
      "LLM: Edit code",
      function()
        local buf = vim.api.nvim_get_current_buf()
        local content = lib.buffer.current.get_text()
        create_enhanced_input("Edit", function(change_prompt)
          vim.b.llm_original_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
          setup_cancel_autocmd(buf)
          edit(content, change_prompt, function(result)
            if result then
              local lines = vim.split(result, "\n", {})
              vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            end
          end)
        end)
      end,
    },
    {
      "n",
      "LLM: Ask entire buffer",
      function()
        local code = lib.buffer.current.get_text()
        ask(code)
      end,
    },
    {
      "n",
      "LLM: Switch model",
      function()
        switch_model()
      end,
    },
    {
      "n",
      "LLM: Set thinking budget",
      function()
        vim.ui.input({
          prompt = string.format("Thinking budget (current: %d, min: 1024): ", state.thinking_budget),
          default = tostring(state.thinking_budget),
        }, function(budget_input)
          if budget_input then
            local budget = tonumber(budget_input)
            if budget and budget >= 1024 then
              state.thinking_budget = budget
              vim.notify(string.format("Thinking budget set to %d tokens", budget), vim.log.levels.INFO)
            else
              vim.notify("Invalid budget. Must be >= 1024", vim.log.levels.ERROR)
            end
          end
        end)
      end,
    },
  },
})

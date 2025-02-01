local CHAT_ENDPOINT = "https://api.openai.com/v1/chat/completions"
local API_KEY = os.getenv("OPENAI_API_KEY")
local DEBUG = false

---@class GPTOptions
---@field model? string
---@field reasoning_effort? string
---@field max_completion_tokens? number

---@class GPTMessage
---@field role string
---@field content string

local function setup_cancel_autocmd(buf)
  local group = "GPTBufferChange_" .. buf
  vim.api.nvim_create_augroup(group, { clear = true })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    buffer = buf,
    callback = function()
      if vim.b.gpt_job_id then
        local current = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
        if current ~= vim.b.gpt_original_text then
          vim.ui.input(
            { prompt = "Buffer modified while GPT request is in progress. Cancel request? (y/n): " },
            function(input)
              if input and input:lower() == "y" then
                vim.fn.jobstop(vim.b.gpt_job_id)
                vim.b.gpt_job_id = nil
                vim.notify("GPT request canceled", vim.log.levels.INFO)
                vim.api.nvim_clear_autocmds({ group = group, buffer = buf })
              else
                local orig_lines = vim.split(vim.b.gpt_original_text, "\n")
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, orig_lines)
                vim.notify("Changes reverted. GPT request continues.", vim.log.levels.INFO)
              end
            end
          )
        end
      end
    end,
  })
end

---@param prompt string
---@param options? GPTOptions
---@param callback fun(result:string|nil)
local async_complete = function(prompt, options, callback)
  local messages = {
    { role = "developer", content = prompt },
  }
  local opts = vim.tbl_deep_extend("force", {
    model = "o3-mini",
    reasoning_effort = "medium",
    max_completion_tokens = 100000,
    n = 1,
  }, options or {})

  local payload = vim.tbl_deep_extend("force", opts, { messages = messages })
  local tmpfile = vim.fn.tempname()
  lib.fs.file.write(tmpfile, vim.fn.json_encode(payload))

  local command = string.format(
    "curl -s -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -d '@%s' %s",
    API_KEY,
    tmpfile,
    CHAT_ENDPOINT
  )

  if DEBUG then log("GPT async request: ", { command = command, payload = payload }) end

  -- popup
  local columns = vim.o.columns
  local loading_popup = require("nui.popup")({
    position = { row = 1, col = columns - 2 },
    size = { width = 30, height = 1 },
    enter = false,
    border = { style = "rounded" },
    win_options = { winblend = 10 },
  })
  loading_popup:mount()
  vim.api.nvim_buf_set_lines(loading_popup.bufnr, 0, -1, false, { "LLM call...", "" })

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
        vim.b.gpt_job_id = nil
      end)
      local output = table.concat(output_lines, "\n")
      local status, response = pcall(vim.fn.json_decode, output)
      if not status or not (response and response.choices) then
        if DEBUG then log("GPT fail: ", { request = payload, response = output }) end
        vim.schedule(function()
          callback(nil)
        end)
        return
      end
      local message = response.choices[1].message
      local result = vim.fn.trim(message.content, "\n")
      vim.schedule(function()
        callback(result)
      end)
    end,
  })

  vim.b.gpt_job_id = job_id
end

---@param prompt string
---@param options? GPTOptions
---@param callback fun(result:string|nil)
local complete = function(prompt, options, callback)
  async_complete(prompt, options, callback)
end

---Explain the given code.
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
  complete(prompt, nil, function(result)
    if not result then return end
    result = result:gsub("^%s*(.-)%s*$", "%1")
    local result_lines = vim.split(result, "\n", {})
    local event = require("nui.utils.autocmd").event
    local popup = require("nui.popup")({
      enter = true,
      focusable = true,
      border = { style = "rounded" },
      position = "50%",
      size = { width = "80%", height = "60%" },
      win_options = { wrap = true },
    })
    popup:mount()
    popup:on(event.BufLeave, function()
      popup:unmount()
    end)
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, result_lines)
    vim.api.nvim_buf_set_option(popup.bufnr, "ft", "markdown")
    popup:on(event.BufEnter, function()
      vim.cmd("normal! gg")
    end)
  end)
end

---Ask a question about the given code.
---@param code string
local ask = function(code)
  local filetype = vim.bo.filetype
  vim.ui.input({ prompt = "Ask: " }, function(input)
    if not input then return end
    local prompt = "```" .. filetype .. "\n" .. code .. "\n```\n\n" .. input
    complete(prompt, nil, function(result)
      if not result then return end
      local result_lines = vim.split(result, "\n", {})
      while result_lines[1] == "" do
        table.remove(result_lines, 1)
      end
      while result_lines[#result_lines] == "" do
        table.remove(result_lines, #result_lines)
      end
      local event = require("nui.utils.autocmd").event
      local popup = require("nui.popup")({
        enter = true,
        focusable = true,
        border = { style = "rounded" },
        position = "50%",
        size = { width = "80%", height = "60%" },
        win_options = { wrap = true },
      })
      popup:mount()
      popup:on(event.BufLeave, function()
        popup:unmount()
      end)
      vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, result_lines)
      vim.api.nvim_buf_set_option(popup.bufnr, "ft", "markdown")
      popup:on(event.BufEnter, function()
        vim.cmd("normal! gg")
      end)
    end)
  end)
end

---Edit code based on the provided instructions.
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
  complete(prompt, { model = "o3-mini", reasoning_effort = "medium" }, function(result)
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
  name = "gpt",
  hosts = "*",
  actions = {
    {
      "n",
      "Codex: Generate code",
      function()
        vim.ui.input({ prompt = "Prompt: " }, function(input)
          if not input then return end
          local buf = vim.api.nvim_get_current_buf()
          vim.b.gpt_original_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
          setup_cancel_autocmd(buf)
          local filename = vim.fn.expand("%:t")
          local filetype = vim.bo.filetype
          local prompt = vim.fn.join({
            "Language: " .. filetype,
            "Filename: " .. filename,
            "Prompt: " .. input,
          }, "\n")
          complete(prompt, { model = "o3-mini", reasoning_effort = "medium" }, function(result)
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
      "Codex: Explain code",
      function()
        local code = lib.buffer.current.get_selected_text()
        explain(code)
      end,
    },
    {
      "v",
      "Codex: Ask",
      function()
        local code = lib.buffer.current.get_selected_text()
        ask(code)
      end,
    },
    {
      "v",
      "Codex: Edit code",
      function()
        local buf = vim.api.nvim_get_current_buf()
        local start_line = vim.fn.getpos("'<")[2] - 1
        local end_line = vim.fn.getpos("'>")[2]
        local content = lib.buffer.current.get_selected_text()
        vim.ui.input({ prompt = "Edit: " }, function(change_prompt)
          if not change_prompt then return end
          vim.b.gpt_original_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
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
      "Codex: Edit code",
      function()
        local buf = vim.api.nvim_get_current_buf()
        local content = lib.buffer.current.get_text()
        vim.ui.input({ prompt = "Edit: " }, function(change_prompt)
          if not change_prompt then return end
          vim.b.gpt_original_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
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
  },
})

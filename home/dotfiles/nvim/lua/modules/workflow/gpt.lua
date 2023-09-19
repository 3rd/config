local COMPLETION_ENDPOINT = "https://api.openai.com/v1/completions"
local CHAT_ENDPOINT = "https://api.openai.com/v1/chat/completions"
local API_KEY = os.getenv("OPENAI_API_KEY")

local DEBUG = true
local TOKEN_ESTIMATION_MARGIN = 50

---@type table<string, { type: string, max_length: number }>
local models = {
  ["gpt-4"] = { type = "chat", max_length = 8191 },
  ["gpt-3.5-turbo"] = { type = "chat", max_length = 4096 },
  ["gpt-3.5-turbo-16k"] = { type = "chat", max_length = 16384 },
  ["gpt-3.5-turbo-instruct"] = { type = "complete", max_length = 4096 },
}

---@class GPTOptions
---@field model? string
---@field max_tokens? number
---@field temperature? number
---@field top_p? number
---@field frequency_penalty? number
---@field presence_penalty? number
---@field n? number
---@field stop? string[]

---@class GPTMessage
---@field role string
---@field content string

local estimate_prompt_tokens = function(prompt)
  return math.floor(vim.fn.strchars(prompt) / 3) + TOKEN_ESTIMATION_MARGIN
end

local estimate_messages_tokens = function(messages)
  local tokens = TOKEN_ESTIMATION_MARGIN
  for _, message in ipairs(messages) do
    tokens = tokens + 3
    tokens = tokens + estimate_prompt_tokens(message.content)
  end
  tokens = tokens + 3
  return tokens
end

---@param payload GPTOptions
local gpt_fetch = function(payload)
  local model = models[payload.model]
  if not model then error("Invalid model: " .. payload.model) end

  local endpoint = model.type == "chat" and CHAT_ENDPOINT or COMPLETION_ENDPOINT

  -- debug
  local estimated_tokens = 0
  if model.type == "chat" then
    ---@diagnostic disable-next-line: undefined-field
    estimated_tokens = estimate_messages_tokens(payload.messages)
  else
    ---@diagnostic disable-next-line: undefined-field
    estimated_tokens = estimate_prompt_tokens(payload.prompt)
  end
  if DEBUG then
    log("GPT request: ", { endpoint = endpoint, estimated_tokens = estimated_tokens, payload = payload })
  end

  local tmpfile = vim.fn.tempname()
  lib.fs.file.write(tmpfile, vim.fn.json_encode(payload))

  local command = string.format(
    "curl -s -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -d '@%s' %s",
    API_KEY,
    tmpfile,
    endpoint
  )
  local response = vim.fn.json_decode(vim.fn.system(command))

  if DEBUG then log("GPT response: ", { response = response }) end

  if response and response.choices then
    if model.type == "chat" then
      return vim.fn.trim(response.choices[1].message.content, "\n")
    else
      return vim.fn.trim(response.choices[1].text, "\n")
    end
  else
    log("GPT fail: ", { request = payload, response = response })
  end
end

---@param messages GPTMessage[]
---@param options? GPTOptions
local gpt_chat = function(messages, options)
  local opts = vim.tbl_deep_extend("force", {
    model = "gpt-4",
    temperature = 0,
    top_p = 0,
    frequency_penalty = 0,
    presence_penalty = 0,
    n = 1,
  }, options or {})

  local model = models[opts.model]
  if not model or model.type ~= "chat" then error("Invalid model for chat: " .. opts.model) end

  local input_tokens = estimate_messages_tokens(messages)
  if opts.max_tokens then
    local remaining_tokens = model.max_length - input_tokens
    if opts.max_tokens > remaining_tokens then
      error("Max tokens too high: " .. opts.max_tokens .. " > " .. remaining_tokens)
    end
  else
    opts.max_tokens = model.max_length - input_tokens
  end

  local payload = vim.tbl_deep_extend("force", opts, { messages = messages })
  return gpt_fetch(payload)
end

---@param prompt string
---@param options? GPTOptions
local gpt_complete = function(prompt, options)
  local opts = vim.tbl_deep_extend("force", {
    model = "gpt-3.5-turbo-instruct",
    temperature = 0,
    top_p = 0,
    frequency_penalty = 0,
    presence_penalty = 0,
    n = 1,
  }, options or {})

  local model = models[opts.model]
  if not model or model.type ~= "complete" then error("Invalid model for completion: " .. opts.model) end

  local input_tokens = estimate_prompt_tokens(prompt)
  if opts.max_tokens then
    local remaining_tokens = model.max_length - input_tokens
    if opts.max_tokens > remaining_tokens then
      error("Max tokens too high: " .. opts.max_tokens .. " > " .. remaining_tokens)
    end
  else
    opts.max_tokens = model.max_length - input_tokens
  end

  local payload = vim.tbl_deep_extend("force", opts, { prompt = prompt })
  return gpt_fetch(payload)
end

---@param prompt string
---@param options? GPTOptions
local complete = function(prompt, options)
  local model_name = options and options.model or "gpt-4"
  local model = models[model_name]
  if not model then error("Invalid model: " .. model_name) end

  if model.type == "chat" then
    local messages = { { role = "system", content = prompt } }
    return gpt_chat(messages, options)
  elseif model.type == "complete" then
    return gpt_complete(prompt, options)
  else
    error("Invalid model type: " .. model.type)
  end
end

---@param prompt string
---@param available_models string[]
---@param min_tokens? number
local get_optimal_model_for_prompt = function(prompt, available_models, min_tokens)
  local prompt_tokens = estimate_prompt_tokens(prompt)
  local min_target_tokens = min_tokens or 1000

  for _, model_name in ipairs(available_models) do
    local model = models[model_name]
    if not model then error("Invalid model: " .. model_name) end

    local remaining_tokens = model.max_length - prompt_tokens
    if remaining_tokens >= min_target_tokens then return model_name end
  end

  error(
    "No model can handle this prompt size: "
      .. prompt_tokens
      .. " + "
      .. min_target_tokens
      .. " = "
      .. prompt_tokens + min_target_tokens
  )
end

local explain = function(code)
  local filename = vim.fn.expand("%:t")
  local filetype = vim.bo.filetype

  local prompt = vim.fn.join({
    "Explain what the following code does.\n",
    "Filename: " .. filename,
    "Content:\n```" .. filetype .. "\n" .. code .. "\n```",
    "Explanation:",
  }, "\n")
  local result = complete(prompt)

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
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, result_lines)
  vim.api.nvim_buf_set_option(popup.bufnr, "ft", "markdown")
  popup:on(event.BufEnter, function()
    vim.cmd("normal! gg")
  end)
end

local ask = function(code)
  local filetype = vim.bo.filetype

  vim.ui.input({ prompt = "Ask: " }, function(input)
    if input == nil then return end

    local prompt = "```" .. filetype .. "\n" .. code .. "\n```\n\n" .. input
    local result = complete(prompt)

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
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, result_lines)
    vim.api.nvim_buf_set_option(popup.bufnr, "ft", "markdown")
    popup:on(event.BufEnter, function()
      vim.cmd("normal! gg")
    end)
  end)
end

local edit = function(code, instructions)
  local filetype = vim.bo.filetype
  local filename = vim.fn.expand("%:t")

  local prompt = table.concat({
    "Language: " .. filetype,
    "Filename: " .. filename,
    "Content:\n```" .. filetype .. "\n" .. code .. "\n```",
    "",
    "Instructions: " .. instructions,
  }, "\n")

  local model_name = get_optimal_model_for_prompt(prompt, {
    --
    "gpt-3.5-turbo-instruct",
    "gpt-4",
    "gpt-3.5-turbo-16k",
  })
  local model = models[model_name]

  if model.type == "complete" then
    prompt = table.concat({
      prompt,
      "",
      "Result:",
      "```" .. filetype,
    }, "\n")
  end

  local result = complete(prompt, { model = model_name })

  -- handle code blocks
  local start_idx, end_idx = string.find(result, "```[%w-]+\n(.+)```")
  if start_idx and end_idx then
    local _, _, block_content = string.find(string.sub(result, start_idx, end_idx), "```[%w-]+\n(.+)```")
    result = vim.fn.trim(block_content, "\n")
  end

  return result
end

local generate_tests = function()
  local filename = vim.fn.expand("%:t")
  local filetype = vim.bo.filetype
  local lines = lib.buffer.current.get_lines()
  local content = table.concat(lines, "\n")

  local notes = vim.fn.input({ prompt = "Notes: " })
  log("Generating...")

  local messages = {
    {
      role = "system",
      content = "You are a very advanced test code generation machine. You write clean, consistent, and high-quality code. You will receive the filename of a file, and its content, and you will generate the corresponding test file.",
    },
    {
      role = "system",
      content = "Filename: AvatarButton.tsx" .. filename .. "\nContent:\n```" .. [[
import React, { useState } from "react";
import { Avatar, Box, Tooltip } from '@mui/material';

interface User = {
  name: string;
  image: string;
}

interface AvatarButtonProps {
  user: User;
  onClick?: () => void;
  onMouseEnter?: () => void;
  onMouseLeave?: () => void;
}

export const AvatarButton = ({ user, onClick, onMouseEnter, onMouseLeave }: AvatarButtonProps) => {
  return <Box
    data-testid="avatar-button">
    onMouseEnter={onMouseEnter}
    onMouseLeave={onMouseLeave}
  >
    <Tooltip title={user.name}>
      <button data-testid="button" onClick={onClick}>
        <Avatar data-testid="image" src={image} />
      </button>
    </Tooltip>
  </Box>;
}
]] .. filetype .. "\n" .. content .. "\n```",
    },
    {
      role = "assistant",
      content = [[```tsx
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { AvatarButton } from './AvatarButton';

describe('AvatarButton', () => {
  let onClick: jest.Mock;
  let onMouseEnter: jest.Mock;
  let onMouseLeave: jest.Mock;

  const user = {
    name: 'John Doe',
    image: 'https://example.com/image.png',
  }

  beforeEach(() => {
    jest.clearAllMocks();
    onClick = jest.fn();
    onMouseEnter = jest.fn();
    onMouseLeave = jest.fn();
  });

  it('renders the elements', () => {
    render(<AvatarButton user={user} onClick={onClick} onMouseEnter={onMouseEnter} onMouseLeave={onMouseLeave} />);

    expect(screen.getByTestId('avatar-button')).toBeInTheDocument();
    expect(screen.getByTestId('button')).toBeInTheDocument();
    expect(screen.getByTestId('image')).toBeInTheDocument();
    expect(screen.getByTestId('image')).toHaveAttribute('src', user.image);
  });

  it('calls onClick when the button is clicked', () => {
    render(<AvatarButton user={user} onClick={onClick} onMouseEnter={onMouseEnter} onMouseLeave={onMouseLeave} />);

    userEvent.click(screen.getByTestId('button'));
    expect(onClick).toHaveBeenCalled();
  });

  it('calls onMouseEnter when the button is hovered', () => {
    render(<AvatarButton user={user} onClick={onClick} onMouseEnter={onMouseEnter} onMouseLeave={onMouseLeave} />);

    userEvent.hover(screen.getByTestId('button'));
    expect(onMouseEnter).toHaveBeenCalled();
  });

  it('calls onMouseLeave when the button is unhovered', () => {
    render(<AvatarButton user={user} onClick={onClick} onMouseEnter={onMouseEnter} onMouseLeave={onMouseLeave} />);

    const button = screen.getByTestId('button');
    userEvent.hover(button);
    expect(onMouseLeave).not.toHaveBeenCalled();
    userEvent.unhover(button);
    expect(onMouseLeave).toHaveBeenCalled();
  });
});
]],
    },
    {
      role = "system",
      content = "Filename: "
        .. filename
        .. (notes and "\nNotes:\n" .. notes or "")
        .. "\nContent:\n```"
        .. filetype
        .. "\n"
        .. content
        .. "\n```",
    },
  }

  local result = gpt_chat(messages)
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
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, result_lines)
  vim.api.nvim_buf_set_option(popup.bufnr, "ft", "markdown")
  popup:on(event.BufEnter, function()
    vim.cmd("normal! gg")
  end)
end

return lib.module.create({
  name = "gpt",
  plugins = {
    -- {
    --   "james1236/backseat.nvim",
    --   event = "VeryLazy",
    --   opts = {
    --     openai_api_key = API_KEY,
    --     openai_model_id = "gpt-3.5-turbo",
    --     split_threshold = 100,
    --     -- additional_instruction = "",
    --   },
    -- },
  },
  actions = {
    {
      "n",
      "Codex: Generate code",
      function()
        vim.ui.input({ prompt = "Prompt: " }, function(input)
          if input == nil then return end

          local filename = vim.fn.expand("%:t")
          local filetype = vim.bo.filetype

          local prompt = vim.fn.join({
            "Language: " .. filetype,
            "Filename: " .. filename,
            "Prompt: " .. input,
          }, "\n")

          local model = get_optimal_model_for_prompt(prompt, { "gpt-3.5-turbo-instruct", "gpt-4", "gpt-3.5-turbo-16k" })
          local result = complete(prompt, { model = model })

          local lines = vim.split(result, "\n", {})
          vim.api.nvim_put(lines, "l", true, true)
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
        local bufnr = vim.api.nvim_get_current_buf()
        local start_line = vim.fn.getpos("'<")[2] - 1
        local end_line = vim.fn.getpos("'>")[2]
        local content = lib.buffer.current.get_selected_text()

        vim.ui.input({ prompt = "Edit: " }, function(change_prompt)
          if not change_prompt then return end

          local result = edit(content, change_prompt)

          local lines = vim.split(result, "\n", {})
          vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, lines)
        end)
      end,
    },
    {
      "n",
      "Codex: Edit code",
      function()
        local content = lib.buffer.current.get_text()

        vim.ui.input({ prompt = "Edit: " }, function(change_prompt)
          if change_prompt == nil then return end

          local result = edit(content, change_prompt)

          local lines = vim.split(result, "\n", {})
          vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        end)
      end,
    },
    {
      "n",
      "Codex: Generate tests",
      function()
        generate_tests()
      end,
    },
  },
})

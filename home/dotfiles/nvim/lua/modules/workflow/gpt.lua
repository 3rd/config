local COMPLETION_ENDPOINT = "https://api.openai.com/v1/engines/davinci-codex/completions"
local CHAT_ENDPOINT = "https://api.openai.com/v1/chat/completions"
local API_KEY = os.getenv("OPENAI_API_KEY")

local gpt_complete = function(prompt, max_tokens, stops)
  local body = {
    model = "code-davinci-002",
    prompt = prompt,
    max_tokens = max_tokens or 500,
    temperature = 0.2,
    top_p = 0,
    frequency_penalty = 0,
    presence_penalty = 0,
    n = 1,
  }
  if stops then body.stop = stops end

  local tmpfile = vim.fn.tempname()
  lib.fs.file.write(tmpfile, vim.fn.json_encode(body))

  local response = vim.fn.json_decode(
    vim.fn.system(
      string.format(
        "curl -s -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -d '@%s' %s",
        API_KEY,
        tmpfile,
        COMPLETION_ENDPOINT
      )
    )
  )

  if response and response.choices then
    return response.choices[1].text
  else
    log("GPT fail: ", {
      request = body,
      response = response,
    })
  end
end

local gpt_chat = function(messages, stops)
  local body = {
    model = "gpt-3.5-turbo",
    -- model = "gpt-4",
    messages = messages,
    temperature = 0,
    top_p = 0,
    frequency_penalty = 0,
    presence_penalty = 0,
  }
  if stops then body.stop = stops end

  local tmpfile = vim.fn.tempname()
  lib.fs.file.write(tmpfile, vim.fn.json_encode(body))

  local response = vim.fn.json_decode(
    vim.fn.system(
      string.format(
        "curl -s -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -d '@%s' %s",
        API_KEY,
        tmpfile,
        CHAT_ENDPOINT
      )
    )
  )

  if response and response.choices then
    return response.choices[1].message.content
  else
    log("GPT fail: ", {
      request = body,
      response = response,
    })
  end
end

local explain = function(code)
  local filename = vim.fn.expand("%:t")
  local filetype = vim.bo.filetype

  local messages = {
    {
      role = "system",
      content = "Explain what the following code does.\n"
        .. "Filename: "
        .. filename
        .. "\nContent:\n```"
        .. filetype
        .. "\n"
        .. code
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
    border = {
      style = "rounded",
    },
    position = "50%",
    size = {
      width = "80%",
      height = "60%",
    },
  })
  popup:mount()
  popup:on(event.BufLeave, function()
    popup:unmount()
  end)
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, result_lines)
  vim.api.nvim_buf_set_option(popup.bufnr, "ft", "markdown")
  vim.api.nvim_buf_set_option(popup.bufnr, "wrap", true)
  popup:on(event.BufEnter, function()
    vim.cmd("normal! gg")
  end)
end

local ask = function(code)
  local filetype = vim.bo.filetype

  vim.ui.input({ prompt = "Ask: " }, function(input)
    if input == nil then return end
    local messages = {
      {
        role = "system",
        content = "```" .. filetype .. "\n" .. code .. "\n```\n\n" .. input,
      },
    }

    local result = gpt_chat(messages)
    result = result:gsub("^%s*(.-)%s*$", "%1")
    local result_lines = vim.split(result, "\n", {})

    local event = require("nui.utils.autocmd").event
    local popup = require("nui.popup")({
      enter = true,
      focusable = true,
      border = {
        style = "rounded",
      },
      position = "50%",
      size = {
        width = "80%",
        height = "60%",
      },
    })
    popup:mount()
    popup:on(event.BufLeave, function()
      popup:unmount()
    end)
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, result_lines)
    vim.api.nvim_buf_set_option(popup.bufnr, "ft", "markdown")
    vim.api.nvim_buf_set_option(popup.bufnr, "wrap", true)
    popup:on(event.BufEnter, function()
      vim.cmd("normal! gg")
    end)
  end)
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
    border = {
      style = "rounded",
    },
    position = "50%",
    size = {
      width = "80%",
      height = "60%",
    },
  })
  popup:mount()
  popup:on(event.BufLeave, function()
    popup:unmount()
  end)
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, result_lines)
  vim.api.nvim_buf_set_option(popup.bufnr, "ft", "markdown")
  popup:on(event.BufEnter, function()
    vim.cmd("normal! gg")
    vim.api.nvim_buf_set_option(popup.bufnr, "wrap", true)
  end)
end

local setup_backseat = function()
  require("backseat").setup({
    openai_api_key = API_KEY,
    openai_model_id = "gpt-3.5-turbo",
    split_threshold = 100,
    -- additional_instruction = "",
  })
end

return lib.module.create({
  name = "gpt",
  plugins = {
    {
      "james1236/backseat.nvim",
      event = "VeryLazy",
      config = setup_backseat,
    },
  },
  actions = {
    {
      "n",
      "Codex: Generate code",
      function()
        vim.ui.input({ prompt = "Prompt: " }, function(prompt)
          if prompt == nil then return end
          vim.ui.input({ prompt = "Max tokens: " }, function(max_tokens)
            if max_tokens == nil then return end
            local result = gpt_complete(prompt, tonumber(max_tokens))
            vim.api.nvim_put({ result }, "l", true, true)
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
        local bufnr = vim.api.nvim_get_current_buf()
        local start_line = vim.fn.getpos("'<")[2] - 1
        local end_line = vim.fn.getpos("'>")[2]
        local filetype = vim.bo.filetype

        local content = lib.buffer.current.get_selected_text()

        vim.ui.input({ prompt = "Edit: " }, function(change_prompt)
          if change_prompt == nil then return end

          local messages = {
            {
              role = "system",
              content = "Edit the following code according to the following instructions:\n"
                .. change_prompt
                .. "\n"
                .. "Reply only with the complete resulting code after the changes have been made, with no other explainations or comments.\n"
                .. "\n```"
                .. filetype
                .. "\n"
                .. content
                .. "\n```",
            },
          }

          local result = gpt_chat(messages)
          result = result:gsub("^%s*(.-)%s*$", "%1")
          result = result:gsub("```" .. filetype .. "\n", "")
          result = result:gsub("\n```", "")
          local result_lines = vim.split(result, "\n", {})

          -- local result = edit(code, change_prompt)
          -- log("bufnr: ", bufnr, " start: ", start_line, " end: ", end_line)
          -- log("result:", result)
          -- local result_lines = vim.split(result, "\n", {})

          vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, result_lines)
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

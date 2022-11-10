local lib = require("lib")

local COMPLETION_ENDPOINT = "https://api.openai.com/v1/engines/davinci-codex/completions"
local EDIT_ENDPOINT = "https://api.openai.com/v1/edits"
local API_KEY = os.getenv("OPENAI_API_KEY")

local complete = function(prompt, max_tokens, stops)
  local body = {
    prompt = prompt,
    max_tokens = max_tokens or 400,
    temperature = 0,
    top_p = 1,
    frequency_penalty = 0,
    presence_penalty = 0.6,
    n = 1,
  }
  if stops then body.stop = stops end

  local tmpfile = vim.fn.tempname()
  lib.shell.write_file(tmpfile, vim.fn.json_encode(body))

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

  if response.choices then
    return response.choices[1].text
  else
    log("GPT fail: ", {
      request = body,
      response = response,
    })
  end
end

local edit = function(input, instruction)
  local body = {
    model = "code-davinci-edit-001",
    input = input,
    instruction = instruction,
    temperature = 0,
    top_p = 1,
  }

  local tmpfile = vim.fn.tempname()
  lib.shell.write_file(tmpfile, vim.fn.json_encode(body))

  local response = vim.fn.json_decode(
    vim.fn.system(
      string.format(
        "curl -s -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -d '@%s' %s",
        API_KEY,
        tmpfile,
        EDIT_ENDPOINT
      )
    )
  )
  -- log(response)
  if response.choices then
    return response.choices[1].text
  else
    log("GPT fail: ", {
      request = body,
      response = response,
    })
  end
end

local explain = function(code)
  local prompt = string.format(
    [[%s
Explanation of the code above, followed by two newlines:
1. We]],
    code
  )
  local completion = complete(prompt, 300, { "\n\n" })
  -- log(completion)
  local result = "1. We" .. completion
  local result_lines = vim.split(result, "\n")

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
  popup:on(event.BufLeave, function() popup:unmount() end)
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, result_lines)
end

return require("lib").module.create({
  name = "gpt",
  actions = {
    {
      "n",
      "Codex: Generate code",
      function()
        vim.ui.input("Prompt: ", function(prompt)
          if prompt == nil then return end
          vim.ui.input("Max tokens: ", function(max_tokens)
            if max_tokens == nil then return end
            local result = complete(prompt, tonumber(max_tokens))
            vim.api.nvim_put({ result }, "l", true, true)
          end)
        end)
      end,
    },
    {
      "v",
      "Codex: Explain code",
      function()
        local code = require("lib").buffer.current.get_selected_text()
        explain(code)
      end,
    },
    {
      "v",
      "Codex: Edit code",
      function()
        local bufnr = vim.api.nvim_get_current_buf()
        local start_line = vim.fn.getpos("'<")[2] - 1
        local end_line = vim.fn.getpos("'>")[2]

        local code = require("lib").buffer.current.get_selected_text()
        vim.ui.input("Edit: ", function(change_prompt)
          if change_prompt == nil then return end
          local result = edit(code, change_prompt)
          -- log("bufnr: ", bufnr, " start: ", start_line, " end: ", end_line)
          -- log("result:", result)
          vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, vim.split(result, "\n"))
        end)
      end,
    },
  },
})

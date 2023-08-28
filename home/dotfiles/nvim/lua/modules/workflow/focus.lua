local setup_peepsight = function()
  require("peepsight").setup({
    -- lua
    "function_definition",
    -- go
    "func_literal",
    "function_declaration",
    "method_declaration",
    -- typescript
    "arrow_function",
    "function_declaration",
    "generator_function_declaration",
    "method_definition",
  })
end

return lib.module.create({
  enabled = false,
  name = "workflow/focus",
  plugins = {
    {
      "koenverburg/peepsight.nvim",
      config = setup_peepsight,
      cmd = { "Peepsight" },
    },
  },
  actions = {
    { "n", "Peepsight: Toggle context focusing", "Peepsight" },
  },
})

return lib.module.create({
  name = "fun",
  plugins = {
    {
      "eandrju/cellular-automaton.nvim",
      cmd = {
        "CellularAutomaton",
      },
    },
  },
  actions = {
    { "n", "Fun: Automaton Rain", ":CellularAutomaton make_it_rain<cr>" },
    { "n", "Fun: Automaton Game of Life", ":CellularAutomaton game_of_life<cr>" },
  },
})

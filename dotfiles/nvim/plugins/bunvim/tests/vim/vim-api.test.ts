import { expect, test } from "bun:test";
import { runEditorScenario } from "../run-editor";

test.each(["vim-api", "vim-callbacks"])(
  "%s through a real Neovim host",
  async (scenario) => {
    expect(await runEditorScenario(`${import.meta.dir  }/${  scenario  }.lua`)).toEqual({
      exitCode: 0,
      output: `Bunvim ${  scenario  } passed\n`,
    });
  },
  30_000,
);

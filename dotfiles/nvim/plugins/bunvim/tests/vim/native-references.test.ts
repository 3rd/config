import { expect, test } from "bun:test";
import { runEditorScenario } from "../run-editor";

test("native references through a real Neovim host", async () => {
  expect(await runEditorScenario(`${import.meta.dir  }/native-references.lua`)).toEqual({
    exitCode: 0,
    output: "Bunvim native-references passed\n",
  });
}, 30_000);

import { expect, test } from "bun:test";
import { runEditorScenario } from "../run-editor";

test("scoped variables and native option operations through a real Neovim host", async () => {
  expect(await runEditorScenario(`${import.meta.dir  }/scoped-state.lua`)).toEqual({
    exitCode: 0,
    output: "Bunvim scoped-state passed\n",
  });
}, 30_000);

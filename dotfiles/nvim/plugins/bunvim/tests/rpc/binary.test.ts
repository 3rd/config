import { expect, test } from "bun:test";
import { runEditorScenario } from "../run-editor";

test("Lua codec preserves marked bytes, text, and native references", async () => {
  expect(await runEditorScenario(`${import.meta.dir  }/binary-codec.lua`)).toEqual({
    exitCode: 0,
    output: "Bunvim binary-codec passed\n",
  });
});

test("binary SDK values and Vim APIs preserve bytes through Neovim", async () => {
  expect(await runEditorScenario(`${import.meta.dir  }/binary.lua`)).toEqual({
    exitCode: 0,
    output: "Bunvim binary passed\n",
  });
}, 30_000);

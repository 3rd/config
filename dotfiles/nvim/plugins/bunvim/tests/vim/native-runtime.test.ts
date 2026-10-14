import { expect, test } from "bun:test";
import { runEditorScenario } from "../run-editor";

test("native references enforce plugin ownership and release server state", async () => {
  expect(await runEditorScenario(`${import.meta.dir  }/native-runtime.lua`)).toEqual({
    exitCode: 0,
    output: "Bunvim native-runtime passed\n",
  });
}, 30_000);

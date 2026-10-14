import { expect, test } from "bun:test";
import { runEditorScenario } from "../../tests/run-editor";

test("PickColorscheme previews navigation, accepts selections, and restores colors on cancellation and cleanup", async () => {
  expect(await runEditorScenario(`${import.meta.dir}/colorscheme-picker_spec.lua`)).toEqual({
    exitCode: 0,
    output: "Colorscheme picker passed\n",
  });
}, 30_000);

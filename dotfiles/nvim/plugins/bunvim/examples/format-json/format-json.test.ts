import { expect, test } from "bun:test";
import { runEditorScenario } from "../../tests/run-editor";

test("FormatJSON formats buffers and ranges without overwriting invalid or stale text", async () => {
  expect(await runEditorScenario(`${import.meta.dir}/format-json_spec.lua`)).toEqual({
    exitCode: 0,
    output: "Format JSON passed\n",
  });
}, 30_000);

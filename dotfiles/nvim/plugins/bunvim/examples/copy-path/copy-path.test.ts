import { expect, test } from "bun:test";
import { runEditorScenario } from "../../tests/run-editor";

test("CopyFilePath copies the initiating file and reports unnamed buffers and missing clipboards", async () => {
  expect(await runEditorScenario(`${import.meta.dir}/copy-path_spec.lua`)).toEqual({
    exitCode: 0,
    output: "Copy path passed\n",
  });
}, 30_000);

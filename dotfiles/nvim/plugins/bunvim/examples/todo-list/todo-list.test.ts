import { expect, test } from "bun:test";
import { runEditorScenario } from "../../tests/run-editor";

test("TodoList creates navigable entries in the initiating buffer and clears empty results", async () => {
  expect(await runEditorScenario(`${import.meta.dir}/todo-list_spec.lua`)).toEqual({
    exitCode: 0,
    output: "TODO list passed\n",
  });
}, 30_000);

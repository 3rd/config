import { expect, test } from "bun:test";
import { runEditorScenario } from "../run-editor";

test("subscriptions through a real Neovim host", async () => {
  expect(await runEditorScenario(`${import.meta.dir  }/subscriptions.lua`)).toEqual({
    exitCode: 0,
    output: "Bunvim subscriptions passed\n",
  });
}, 30_000);

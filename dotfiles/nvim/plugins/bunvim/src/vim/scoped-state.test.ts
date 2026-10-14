import { expect, test } from "bun:test";
import { createScopedState } from "./scoped-state";

test("scoped state rejects cancellation before sending or accepting a result", async () => {
  const controller = new AbortController();
  const response = Promise.withResolvers<object>();
  let calls = 0;
  const vim = createScopedState({
    signal: controller.signal,
    nvim: {
      request: () => {
        calls += 1;
        return response.promise;
      },
    },
  });
  const pending = vim.g.get("value");
  controller.abort(new Error("Scoped state canceled"));
  response.resolve({});
  await expect(pending).rejects.toThrow("Scoped state canceled");
  await expect(vim.g.set("value", "stale write")).rejects.toThrow("Scoped state canceled");
  expect(calls).toBe(1);
});

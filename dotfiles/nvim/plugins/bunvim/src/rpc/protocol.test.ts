import { expect, test } from "bun:test";
import { isRpcValue, parseOrigin } from "./protocol";

test("wire results preserve nested values and reject lossy or cyclic values", () => {
  expect(isRpcValue({ count: 3, items: [false, null, "hello"] })).toBe(true);
  expect(isRpcValue({ content: new Uint8Array([0, 128, 255]) })).toBe(true);
  expect(isRpcValue({ count: Number.NaN })).toBe(false);
  expect(isRpcValue(new Date())).toBe(false);
  const cyclic: unknown[] = [];
  cyclic.push(cyclic);
  expect(isRpcValue(cyclic)).toBe(false);
});

test("invocations require the captured buffer, window, and working directory", () => {
  expect(parseOrigin([12, 1001, "/project"])).toEqual({
    buffer: 12,
    window: 1001,
    cwd: "/project",
  });
  expect(() => parseOrigin(["12", 1001, "/project"])).toThrow("buffer must be an integer");
});

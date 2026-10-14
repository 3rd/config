import { expect, test } from "bun:test";
import { decodeRpcValue, encodeRpcValue, RpcEncodingError } from "./value-codec";

test("nested binary values preserve slices and ordinary UTF-8 text", () => {
  const bytes = new Uint8Array([1, 0, 128, 192, 255, 2]).subarray(1, 5);
  const value = { text: "héllo 🐇", values: [bytes, null, false, 3] };
  expect(decodeRpcValue(encodeRpcValue(value))).toEqual(value);
  expect(decodeRpcValue(encodeRpcValue(new Uint8Array()))).toEqual(new Uint8Array());
});

test("tag-shaped user values cannot impersonate binary or native references", () => {
  const value = [
    ["bytes", "AIDA/w=="],
    ["reference", "scope", 1, "TSNode"],
    { scope: "scope", id: 1, type: "TSNode" },
    Object.fromEntries([["__proto__", { isNative: true }]]),
  ];
  expect(decodeRpcValue(encodeRpcValue(value))).toEqual(value);

  const reference = {};
  const token = { scope: "scope", id: 1, type: "TSNode" };
  const wire = encodeRpcValue([reference], {
    encodeReference: (value) => (value === reference ? token : undefined),
  });
  expect(
    decodeRpcValue(wire, {
      decodeReference: (decoded) => {
        expect(decoded).toEqual(token);
        return reference;
      },
    }),
  ).toEqual([reference]);
  expect(() => decodeRpcValue(wire)).toThrow("RPC references are not supported here");
});

test("undefined normalization applies only to explicitly normalized Vim arguments", () => {
  const value = [undefined, { omitted: undefined, present: null }];
  expect(() => encodeRpcValue(value)).toThrow("Cannot encode RPC value");
  expect(decodeRpcValue(encodeRpcValue(value, { undefinedValues: "normalize" }))).toEqual([
    null,
    { present: null },
  ]);
});

test("encoding errors distinguish unsupported values from caller failures", () => {
  expect(() => encodeRpcValue(() => null)).toThrow(RpcEncodingError);
  const failure = new TypeError("Caller failure");
  const value = {
    get field() {
      throw failure;
    },
  };
  expect(() => encodeRpcValue(value)).toThrow(failure);
  expect(() =>
    encodeRpcValue(
      {},
      {
        encodeReference: () => {
          throw failure;
        },
      },
    ),
  ).toThrow(failure);
});

test("cyclic, lossy, and malformed wire values fail before use", () => {
  const cycle: unknown[] = [];
  cycle.push(cycle);
  expect(() => encodeRpcValue(cycle)).toThrow("Cannot encode RPC value");
  expect(() => encodeRpcValue(new Date())).toThrow("Cannot encode RPC value");
  expect(() => encodeRpcValue(Number.NaN)).toThrow("Cannot encode RPC value");
  expect(() => decodeRpcValue(["bytes", "AB=="])).toThrow("Invalid encoded RPC bytes");
  expect(() => decodeRpcValue(["array", {}])).toThrow("Invalid encoded RPC value");
  expect(() =>
    decodeRpcValue([
      "object",
      [
        ["same", 1],
        ["same", 2],
      ],
    ]),
  ).toThrow("Invalid encoded RPC object entry");
  expect(() => decodeRpcValue(["reference", "scope", 0, "TSNode"])).toThrow("Invalid RPC reference");
});

import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";

const clipboardScript = readFileSync(new URL("./keep-clipboard.js", import.meta.url), "utf8");

const createClipboardData = (value: string) => ({
  toBase64: () => Buffer.from(value).toString("base64"),
  toString: () => value,
});

type ClipboardFixture = {
  capturedItem: Record<string, string>;
  currentItem: Record<string, string>;
};

const runClipboardScript = ({ capturedItem, currentItem }: ClipboardFixture) => {
  const copies: Record<string, string>[] = [];
  runInNewContext(clipboardScript, {
    isClipboard: () => true,
    hasData: () => Object.values(capturedItem).some((value) => value.trim().length > 0),
    dataFormats: () => Object.keys(capturedItem),
    data: (format: string) => createClipboardData(capturedItem[format] ?? ""),
    clipboard: (format: string) => createClipboardData(currentItem[format] ?? ""),
    str: String,
    copy: (item: Record<string, ReturnType<typeof createClipboardData>>) => {
      copies.push(Object.fromEntries(
        Object.entries(item).map(([format, value]) => [format, String(value)]),
      ));
    },
  });

  return copies;
};

test("retains the current clipboard instead of a stale automatic-command event", () => {
  const copies = runClipboardScript({
    capturedItem: { "text/plain": "Earlier copy", "image/png": "Earlier image" },
    currentItem: {
      TIMESTAMP: "2",
      "?": "TIMESTAMP\ntext/plain\ntext/html\napplication/x-copyq-owner\nTARGETS\n",
      "text/plain": "Latest copy",
      "text/html": "<b>Latest copy</b>",
      "application/x-copyq-owner": "current owner",
      TARGETS: "text/plain",
    },
  });
  expect(copies).toEqual([{
    "text/plain": "Latest copy",
    "text/html": "<b>Latest copy</b>",
  }]);
});

test("does not replace a clipboard with no usable current formats", () => {
  const copies = runClipboardScript({
    capturedItem: { "text/plain": "Earlier copy" },
    currentItem: {
      TIMESTAMP: "2",
      "?": "TIMESTAMP\napplication/x-copyq-owner\n",
      "application/x-copyq-owner": "current owner",
    },
  });
  expect(copies).toEqual([]);
});

test("does not publish a snapshot when the clipboard changes during capture", () => {
  let timestamp = "1";
  const copies = runClipboardScript({
    capturedItem: { "text/plain": "Earlier copy" },
    currentItem: {
      get TIMESTAMP() {
        return timestamp;
      },
      get "?"() {
        timestamp = "2";
        return "text/plain\n";
      },
      "text/plain": "Latest copy",
    },
  });
  expect(copies).toEqual([]);
});

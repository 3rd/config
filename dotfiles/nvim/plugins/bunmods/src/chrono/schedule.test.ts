import { expect, test } from "bun:test";
import { parseSchedule } from "./schedule";

test.each([
  { name: "numeric hour", input: "9", expected: "2026.10.12 9:00" },
  { name: "date only", input: "tomorrow", expected: "2026.10.13" },
  {
    name: "explicit time",
    input: "tomorrow at 9:30",
    expected: "2026.10.13 09:30",
  },
  {
    name: "same-day range",
    input: "tomorrow from 9am to 11am",
    expected: "2026.10.13 09:00-11:00",
  },
  {
    name: "multi-day range",
    input: "October 14 to October 16, 2026",
    expected: "2026.10.14 - 2026.10.16 12:00",
  },
  { name: "unrecognized input", input: "not a date", expected: null },
])("formats $name", ({ input, expected }) => {
  expect(parseSchedule(input, new Date(2026, 9, 12, 12))).toBe(expected);
});

import { describe, expect, test } from "bun:test";
import { runCli, runJson } from "gunsmith/testing";
import { createCli } from "./cli";

describe("greet", () => {
  test("prints a human greeting", async () => {
    const result = await runCli(createCli(), ["greet", "Ada"]);
    expect(result.exitCode).toBe(0);
    expect(result.stderr).toBe("");
    expect(result.stdout).toBe("hello Ada\n");
  });

  test("prints an excited human greeting", async () => {
    const result = await runCli(createCli(), ["greet", "Ada", "--excited"]);
    expect(result.exitCode).toBe(0);
    expect(result.stderr).toBe("");
    expect(result.stdout).toBe("hello Ada!\n");
  });

  test("accepts the -e shorthand", async () => {
    const result = await runCli(createCli(), ["greet", "Ada", "-e"]);
    expect(result.exitCode).toBe(0);
    expect(result.stderr).toBe("");
    expect(result.stdout).toBe("hello Ada!\n");
  });

  test("returns structured JSON output", async () => {
    const result = await runJson<{ message: string }>(createCli(), ["greet", "Ada"]);
    expect(result.exitCode).toBe(0);
    expect(result.stderr).toBe("");
    expect(result.json).toEqual({ message: "hello Ada" });
  });

  test("rejects a missing name", async () => {
    const result = await runCli(createCli(), ["greet"]);
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toBe("");
    expect(result.stderr).toContain('error: invalid argument "name":');
  });

  test("rejects a blank name", async () => {
    const result = await runCli(createCli(), ["greet", "   "]);
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toBe("");
    expect(result.stderr).toContain('error: invalid argument "name":');
  });
});

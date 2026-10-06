import { expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const taskScriptPath = fileURLToPath(new URL("./task.sh", import.meta.url));

const runTaskScript = (timeoutBody: string) => {
  const result = spawnSync(
    "bash",
    ["-c", `timeout() {\n${timeoutBody}\n}\nsource "$1"`, "task-test", taskScriptPath],
    {
      encoding: "utf8",
      env: { ...process.env, TASK_ERROR_COLOR: "#ff0000" },
    },
  );
  if (result.error) {
    throw result.error;
  }

  expect(result.status).toBe(0);
  expect(result.stderr).toBe("");
  return result.stdout;
};

test("preserves successful running-task output", () => {
  const output = runTaskScript("printf '%s\\n' 'Example - Task (1s)'; return 0");
  expect(output).toBe("%{F#f97e48}  Example - Task (1s)\n");
});

test("reports a successful empty observation neutrally", () => {
  const output = runTaskScript("return 0");
  expect(output).toBe("No running task\n");
});

test("rejects failed-command stdout and keeps diagnostic text private", () => {
  const output = runTaskScript("printf '%s\\n' 'Partial task'; printf '%s\\n' 'Synthetic diagnostic' >&2; return 1");
  expect(output).toBe("%{F#ff0000}  Task status unavailable%{F-}\n");
});

test("does not infer timeout from a killed command", () => {
  const output = runTaskScript("return 137");
  expect(output).toBe("%{F#ff0000}  Task status unavailable%{F-}\n");
});

test("reports actual timeout expiration", () => {
  const output = runTaskScript("command timeout --verbose --kill-after=0.05 0.05 tail -f /dev/null");
  expect(output).toBe("%{F#ff0000}  Task status timed out%{F-}\n");
});

test("reports timeout expiration requiring a forced kill", () => {
  const output = runTaskScript(`
    command timeout --verbose --kill-after=0.05 0.05 sh -c 'trap "" TERM; exec tail -f /dev/null'
    native_status=$?
    if [ "$native_status" -ne 137 ]; then
      printf 'Expected a forced kill, got status %s\\n' "$native_status"
      return 0
    fi
    return "$native_status"
  `);
  expect(output).toBe("%{F#ff0000}  Task status timed out%{F-}\n");
});

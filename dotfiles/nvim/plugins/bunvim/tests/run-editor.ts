import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

export const runEditorScenario = async (path: string) => {
  const scratch = await mkdtemp(join(tmpdir(), "bunvim-test-"));
  const child = Bun.spawn(["nvim", "--headless", "--clean", "-n", "-i", "NONE", "-l", path], {
    stdout: "pipe",
    stderr: "pipe",
    env: {
      ...process.env,
      XDG_STATE_HOME: scratch,
      NVIM_LOG_FILE: join(scratch, "nvim.log"),
    },
  });
  try {
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(child.stdout).text(),
      new Response(child.stderr).text(),
      child.exited,
    ]);
    return { exitCode, output: stdout + stderr };
  } finally {
    if (child.exitCode === null) {
      child.kill();
      await child.exited;
    }

    await rm(scratch, { recursive: true });
  }
};

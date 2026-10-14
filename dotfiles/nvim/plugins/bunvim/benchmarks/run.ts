import { createHash } from "node:crypto";

const root = `${import.meta.dir  }/..`;
const isSustained = process.argv[2] === "--sustained";
if (process.argv.length > (isSustained ? 3 : 2)) {
  throw new Error("Usage: bun run benchmarks/run.ts [--sustained]");
}

const sources: Record<string, string> = {};
for await (const path of new Bun.Glob("{src,lua,plugin,examples,benchmarks}/**/*.{ts,lua}").scan({
  cwd: root,
})) {
  sources[path] = createHash("sha256")
    .update(await Bun.file(`${root  }/${  path}`).bytes())
    .digest("hex");
}

sources["bun.lock"] = createHash("sha256")
  .update(await Bun.file(`${root  }/bun.lock`).bytes())
  .digest("hex");
const child = Bun.spawn(
  ["nvim", "--headless", "--clean", "-n", "-i", "NONE", "-l", `${import.meta.dir  }/run.lua`],
  {
    stdout: "pipe",
    stderr: "pipe",
    env: { ...process.env, BUNVIM_SUSTAINED: isSustained ? "1" : "" },
  },
);
const [stdout, stderr, exitCode] = await Promise.all([
  new Response(child.stdout).text(),
  new Response(child.stderr).text(),
  child.exited,
]);
if (exitCode !== 0) {
  throw new Error(stderr || stdout);
}

const result: unknown = JSON.parse(stdout);
console.log(JSON.stringify({ date: new Date().toISOString(), bun: Bun.version, sources, result }, null, 2));

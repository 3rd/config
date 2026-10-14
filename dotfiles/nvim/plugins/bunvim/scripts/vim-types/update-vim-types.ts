import { mkdir, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, relative, resolve } from "node:path";
import { format } from "prettier";
import { isRecord } from "../../src/rpc/protocol";
import { generateVimTypes } from "./generate-vim-types";
import { getVimCandidates } from "./vim-inventory";

const run = async (command: string[], options: { env?: NodeJS.ProcessEnv } = {}) => {
  const child = Bun.spawn(command, {
    stdout: "pipe",
    stderr: "pipe",
    env: options.env,
  });
  const [exitCode, stdout, stderr] = await Promise.all([
    child.exited,
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
  ]);
  if (exitCode !== 0 || stderr.trim()) {
    throw new Error(`${command[0]} exited with ${exitCode}:\n${stderr}\n${stdout}`);
  }

  return stdout;
};

const args = process.argv.slice(2);
if (args.length > 1 || (args[0] !== undefined && args[0] !== "--check")) {
  throw new Error("Usage: bun run scripts/vim-types/update-vim-types.ts [--check]");
}

const shouldCheck = args[0] === "--check";
const workspace = await mkdtemp(join(tmpdir(), "bunvim-vim-types-"));
try {
  const env = {
    ...process.env,
    XDG_STATE_HOME: join(workspace, "state"),
    XDG_CACHE_HOME: join(workspace, "cache"),
  };
  const runtime = (
    await run(
      [
        "nvim",
        "--clean",
        "--headless",
        "-n",
        "-i",
        "NONE",
        "+lua io.stdout:write(vim.env.VIMRUNTIME)",
        "+qa!",
      ],
      { env },
    )
  ).trim();
  const luaDirectory = join(runtime, "lua");
  const outputDirectory = join(workspace, "output");
  await mkdir(outputDirectory);
  const config = join(workspace, "config.json");
  await Bun.write(
    config,
    JSON.stringify({
      "runtime.version": "LuaJIT",
      "workspace.checkThirdParty": false,
      "workspace.maxPreload": 20_000,
      "diagnostics.enable": false,
      docScriptPath: `/${  relative(luaDirectory, join(import.meta.dir, "export-vim-types.lua"))}`,
    }),
  );
  console.log("Extracting Neovim LuaCATS metadata with Lua Language Server...");
  await run([
    "lua-language-server",
    `--doc=${  luaDirectory}`,
    `--doc_out_path=${  outputDirectory}`,
    `--logpath=${  join(workspace, "logs")}`,
    `--metapath=${  join(workspace, "meta")}`,
    `--configpath=${  config}`,
  ]);
  const metadata: unknown = await Bun.file(join(outputDirectory, "vim-metadata.json")).json();
  const candidates = join(workspace, "candidates.json");
  const inventory = join(workspace, "inventory.json");
  await Bun.write(candidates, JSON.stringify(getVimCandidates(metadata)));
  await run(
    [
      "nvim",
      "--clean",
      "--headless",
      "-n",
      "-i",
      "NONE",
      "-l",
      join(import.meta.dir, "inspect-vim.lua"),
      candidates,
      inventory,
    ],
    { env },
  );
  const native: unknown = await Bun.file(inventory).json();
  const result = generateVimTypes(metadata, native);
  if (result.coverage.omitted.length > 0) {
    throw new Error(`Vim API generation omitted callable paths: ${  result.coverage.omitted.join(", ")}`);
  }

  const destination = resolve(import.meta.dir, "../../src/vim/generated");
  const manifest = JSON.stringify(
    result.manifest,
    (_key, value: unknown) =>
      isRecord(value) ?
        Object.fromEntries(Object.entries(value).sort(([left], [right]) => left.localeCompare(right)))
      : value,
    2,
  );
  const outputs = new Map([
    ["vim-types.ts", await format(result.declarations, { parser: "typescript" })],
    ["vim-functions.json", `${manifest  }\n`],
    ["vim-coverage.json", `${JSON.stringify(result.coverage, null, 2)  }\n`],
  ]);
  const stale = [];
  for (const [name, content] of outputs) {
    const path = join(destination, name);
    if (shouldCheck) {
      const file = Bun.file(path);
      if (!(await file.exists()) || (await file.text()) !== content) {
        stale.push(name);
      }
    } else {
      await Bun.write(path, content);
    }
  }

  console.log(
    JSON.stringify({
      version: result.manifest.version,
      functions: Object.keys(result.manifest.functions).length,
      constants: Object.keys(result.manifest.constants).length,
      supported: result.coverage.supported.length,
      unsupported: Object.keys(result.coverage.unsupported).length,
      omitted: result.coverage.omitted,
    }),
  );

  if (stale.length > 0) {
    throw new Error(`Stale Vim API output: ${  stale.join(", ")  }. Run bun run generate:vim-types.`);
  }
} finally {
  await rm(workspace, { recursive: true, force: true });
}

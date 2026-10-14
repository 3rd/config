import type { Vim } from "../../src";

interface Choice {
  id: number;
  name: string;
}

const checkVimTypes = async (vim: Vim) => {
  const buffer: number = await vim.api.nvim_get_current_buf();
  const lines: string[] = await vim.api.nvim_buf_get_lines(buffer, 0, -1, true);
  const cwd: string = await vim.fn.getcwd();
  const [uvCwd, uvError, uvErrorName] = await vim.uv.cwd();
  const uvPath: string | null = uvCwd;
  const uvFailure: string | null = uvError;
  const uvCode: string | null = uvErrorName;
  const uvVersion: string = await vim.uv.version_string();
  const scheduled: null = await vim.schedule();
  const deferred: null = await vim.defer_fn(0);
  const exited: [number, number] = await vim.uv.spawn("sh", {
    args: ["-c", "exit 0"],
  });
  const [fileBytes] = await vim.uv.fs_read(1, 8, 0);
  const bytes: Uint8Array | null = fileBytes;
  await vim.uv.fs_write(1, [new Uint8Array([0, 255]), "text"], 0);
  const [randomBytes] = await vim.uv.random(8);
  const random: Uint8Array | null = randomBytes;
  const converted: Uint8Array = await vim.uv.wtf8_to_utf16(new Uint8Array([65]));
  const [interfaces] = await vim.uv.interface_addresses();
  if (interfaces) {
    for (const addresses of Object.values(interfaces)) {
      for (const address of addresses) {
        const mac: Uint8Array = address.mac;
      }
    }
  }

  const [responses, responseContext, responseConfig] = await vim.lsp.buf_request_all(
    0,
    "textDocument/hover",
    {},
  );
  const responseClient: number = responseContext.client_id;
  const canLog: boolean | null = await vim.lsp.log.debug();
  const [stat] = await vim.uv.fs_stat("fixture.txt");
  if (stat !== null) {
    const size: number = stat.size;
    const modifiedAt: number = stat.mtime.sec;
  }

  await vim.uv.fs_lchown("fixture.txt", -1, -1);
  const configPath: string = await vim.fn.stdpath("config");
  const diagnosticConfig = await vim.diagnostic.config();
  const virtualText = diagnosticConfig.virtual_text;
  const undefineResult: -1 | 0 = await vim.fn.sign_undefine();
  const undefineResults: number[] = await vim.fn.sign_undefine(["fixture"]);
  const searchIndex: number = await vim.list.bisect([{ id: 1 }], { id: 2 }, { key: "id" });
  const layout: ["col" | "row", unknown[]] | ["leaf", number] | [] = await vim.fn.winlayout();
  const browsePath: string = await vim.fn.browse(false, "Fixture", "", "");
  const browseDirectory: string = await vim.fn.browsedir("Fixture", "");
  const nodeRange: [number, number, number, number] = await vim.treesitter.get_node_range([1, 2, 3, 4]);
  await vim.lsp.buf.code_action({ context: {} });
  await vim.lsp.config("bunvim_fixture", { cmd: ["unused"] });
  await vim.fn.get(["example"], 0);
  const description: string = await vim.inspect({ name: "example" });
  const version = await vim.version();
  const major: number = version.major;
  const numericMajor: number | undefined = version[1];
  const input: string | null = await vim.ui.input({
    prompt: "Name: ",
    default: undefined,
    scope: "buffer",
  });
  const choices: Choice[] = [{ id: 1, name: "Example" }];
  const selection: [Choice | null, number | null] = await vim.ui.select(choices, { prompt: "Choose" });
  const level: 2 = vim.log.levels.INFO;
  await vim.notify(cwd, level);
  const commandResult: string = await vim.cmd("nohlsearch");
  await vim.cmd.normal({ args: ["gg"], bang: true });
  await vim.api.nvim_echo([["message"]], false);
  await vim.lsp.util.apply_text_edits(
    [
      {
        range: {
          start: { line: 0, character: 0 },
          end: { line: 0, character: 0 },
        },
        newText: "text",
      },
    ],
    buffer,
    "utf-8",
  );

  // @ts-expect-error Buffer handles are numbers.
  await vim.api.nvim_buf_get_lines("buffer", 0, -1, true);
  // @ts-expect-error Option objects reject unknown fields.
  await vim.ui.input({ promt: "Name: " });
  // @ts-expect-error Window-relative positioning is a literal union.
  await vim.api.nvim_open_win(buffer, false, { relative: "viewport" });
  // @ts-expect-error The input callback is replaced by the promise.
  await vim.ui.input({}, () => {});
  // @ts-expect-error Lua-only callbacks cannot be sent across RPC.
  await vim.api.nvim_buf_call(buffer, () => 1);
  // @ts-expect-error The libuv path must be a string.
  await vim.uv.fs_stat(42);
  // @ts-expect-error Native callback overloads are excluded.
  await vim.uv.fs_stat("fixture.txt", () => {});
  // @ts-expect-error Timer handles require native Lua.
  await vim.uv.new_timer();
  // @ts-expect-error Repeating callbacks require a subscription, not a promise.
  await vim.tty.query("Co", {});
  // @ts-expect-error Synchronous mapping callbacks must execute in Lua.
  await vim.tbl_map(() => 1, [1]);
  // @ts-expect-error The completion callback is replaced by the promise.
  await vim.lsp.buf_request_all(0, "textDocument/hover", {}, () => {});
  // @ts-expect-error Binary conversion arguments must preserve bytes.
  await vim.uv.wtf8_to_utf16("text");
  // @ts-expect-error Symbolic-link ownership takes a path, not a descriptor.
  await vim.uv.fs_lchown(1, -1, -1);
  // @ts-expect-error File metadata is numeric.
  const textSize: string | undefined = stat?.size;
  // @ts-expect-error Log functions return a nullable predicate, not text.
  const logText: string = await vim.lsp.log.info("fixture");
  // @ts-expect-error Nested optional tuple fields do not make the array optional.
  await vim.api.nvim_echo(undefined, false);
  // @ts-expect-error Unknown function names have no catch-all signature.
  await vim.api.nvim_not_a_function();
  // @ts-expect-error Regex userdata requires native Lua.
  await vim.regex("abc");
  // @ts-expect-error Process handles require native Lua.
  await vim.system(["true"]);
  // @ts-expect-error Ring buffers retain native instance state.
  await vim.ringbuf(4);
  // @ts-expect-error Iterator constructors require native Lua.
  await vim.iter([1, 2]);
  // @ts-expect-error A private constructor cannot return a native instance across RPC.
  await vim.range.new(0, 0, 0, 0, 1);
  // @ts-expect-error Search keys must name a property of the list elements.
  await vim.list.bisect([{ id: 1 }], { id: 2 }, { key: "missing" });
  // @ts-expect-error RPC does not preserve computed numeric version fields.
  const computedMajor: number = version[1];
  // @ts-expect-error A missing environment variable returns null.
  const missingEnvironment: string = await vim.fn.getenv("BUNVIM_MISSING_FIXTURE");
  // @ts-expect-error Line results preserve their element type.
  const numbers: number[] = await vim.api.nvim_buf_get_lines(buffer, 0, -1, true);

  return {
    buffer,
    lines,
    cwd,
    uvPath,
    uvFailure,
    uvCode,
    uvVersion,
    scheduled,
    deferred,
    exited,
    responses,
    responseClient,
    responseConfig,
    canLog,
    logText,
    textSize,
    configPath,
    virtualText,
    undefineResult,
    undefineResults,
    searchIndex,
    layout,
    nodeRange,
    input,
    selection,
    numbers,
    commandResult,
    description,
    major,
    numericMajor,
    computedMajor,
    browsePath,
    browseDirectory,
    missingEnvironment,
  };
};

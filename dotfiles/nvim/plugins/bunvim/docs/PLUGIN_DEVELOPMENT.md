# Plugin Development

A Bunvim plugin default-exports a setup function that receives a `PluginContext`. Setup can be asynchronous. Keep plugin state inside setup so it resets when the plugin is unloaded and loaded again.

Start with [copy-path](../examples/copy-path/index.ts) for a command using typed Vim calls, or [format-json](../examples/format-json/index.ts) for safe buffer edits. Give each plugin its own directory and Lua configuration entry. See [all four examples](../README.md#examples) for commands and usage.

## Register Entrypoints

The plugin context exposes:

- `registerFunction(name, handler)`: a named function callable from Lua. The handler receives unknown input and an invocation context.
- `registerCommand(options, handler)`: a Neovim user command. Options include `name`, `nargs`, `bang`, `range`, `count`, `complete`, and `desc`. Completion accepts a built-in name or a TypeScript callback.
- `registerKeymap(options, handler)`: a key action. Options include `mode`, `keys`, `buffer`, `silent`, `expr`, and `desc`. Use a `<Plug>` mapping when users should choose their own key.
- `registerAutocmd(options, handler)`: an event handler. Options include `event`, `pattern` or `buffer`, `once`, `desc`, and `execution: "async" | "sync"`.
- `onDispose(cleanup)`: cleanup for the plugin's resources.

Register entrypoints during setup or later. Each registration method returns `{ ready: Promise<void>, dispose(): Promise<void> }`. Setup waits for its registrations. For later registrations, await `ready` before using a command or mapping. Await `dispose()` before reusing its name. Name conflicts fail without replacing editor configuration. If setup throws, Bunvim removes the plugin's resources.

Store registration handles with the state that uses them, such as a buffer's feature state. Repeated removal is safe. Disposing an old function handle cannot remove its replacement. Neovim removes buffer-local autocommands on some buffer renames. For a save hook that must survive the first save, use a global hook and track enabled buffers.

The context also provides `name`, `options`, the typed `vim` API, the `nvim` client, and a `signal` for the plugin's lifetime.

## Use the Vim API

`vim` uses Neovim's namespace and function names. Remote calls return promises, with types generated from the installed Neovim's LuaCATS annotations.

Inside setup:

```ts
plugin.registerFunction("askName", async (_input, { vim }) => {
  const name = await vim.ui.input({ prompt: "Name: " });
  if (name === null) return;

  await vim.notify(`Hello, ${name}`, vim.log.levels.INFO);
  return name;
});

plugin.registerFunction("currentLines", async (_input, { vim }) => {
  const buffer = await vim.api.nvim_get_current_buf();
  return vim.api.nvim_buf_get_lines(buffer, 0, -1, true);
});
```

Here `name` is `string | null`, `buffer` is `number`, and the lines are `string[]`. Buffer and window handles are integers. Callable namespaces work alongside their methods: `await vim.version()` returns version data, while `vim.version.parse()` remains available. `vim.inspect(value)`, `vim.cmd("nohlsearch")`, and `vim.cmd.normal("gg")` also return promises. Constants such as `vim.log.levels.INFO` are ordinary values.

### Completion Callbacks

`vim.ui.input(options)` resolves to a string, including an empty string, or `null` when canceled. `vim.ui.select(items, options)` resolves to `[item, index]`, preserving the item's type and Neovim's one-based index. Cancellation returns `[null, null]`. Both use Neovim's current UI, including plugin overrides. The promise replaces the Lua completion callback; do not pass one.

`await vim.schedule()` resolves after Neovim runs the scheduled callback. `await vim.defer_fn(milliseconds)` resolves after its one-shot timer fires. Both resolve to `null`. TypeScript resumes in Bun, so these waits do not make later editor calls atomic or bypass Neovim's textlock.

`await vim.uv.spawn(program, options)` resolves to `[exitCode, signal]` and closes the native process handle. A nonzero exit code is a result; failure to start rejects the promise. Options requiring native streams are unsupported. Use native Lua for `vim.system()`; this API cannot transport its process object, interactive streams, or arbitrary-byte output.

Serializable `vim.uv` operations include `fs_stat`, `fs_open`, `fs_fstat`, `fs_close`, and `cwd`. Multiple results keep their native order: `await vim.uv.fs_stat(path)` returns `[stat, error, errorName]`, using `null` for absent results. Filesystem and name-resolution calls run asynchronously where supported and return native result tuples, including both success values from `fs_mkstemp` and `getnameinfo`. Raw callbacks, sockets, directory streams, and other native handles are unsupported.

`await vim.lsp.buf_request_all(buffer, method, params)` resolves to `[results, context, config]`. `results` is a dictionary keyed by client ID, even when IDs are consecutive integers. Each entry contains the native response error and result. With no matching clients, the promise rejects with `No LSP clients support this request`. Set `timeout_ms` on the containing Bunvim call to limit how long it waits for a server.

Repeating callbacks and synchronous predicates require native Lua or SDK registration APIs. A promise can replace only a completion callback.

### Values and Types

Calls can send and return finite numbers, strings, booleans, null, `Uint8Array`, arrays, and plain objects. Fixed multiple returns become tuples; variadic returns become arrays. Supported native objects use [scoped references](#use-native-objects).

In Vim calls, optional properties set to `undefined` are omitted. Undefined positional arguments become Lua nil; null and undefined inside arrays become `vim.NIL`. Plugin results cannot contain nested undefined values.

Dynamically typed values and functions without a return annotation use `RpcValue`. Indexed Lua tuple fields become zero-based TypeScript tuples. Numeric convenience fields on metatable-backed records are optional because RPC does not preserve computed properties.

Unsupported APIs such as `vim.regex()` and `vim.system()` are typed as `never` and rejected before Lua runs, including calls from JavaScript. Unsupported callback parameters are also typed as `never`. Functions with unannotated parameters, private native helpers, and incomplete overloads are excluded. Supported overloads and namespace methods remain usable even when other overloads or the namespace itself are unsupported.

Arbitrary functions and userdata cannot cross RPC; optional callback-valued results may be absent. For unsupported operations, use `context.nvim.executeLua` and return only the data TypeScript needs. It also lets you group editor operations atomically.

IntelliSense includes Neovim's descriptions, parameter and option docs, and deprecation notices. Use those docs for index bases, units, and native behavior.

### Binary Data

Use strings for text and `Uint8Array` for bytes. Slices preserve their offset and length. In Lua, wrap bytes with `require("bunvim").bytes(value)` and unwrap returned bytes with `require("bunvim").bytes_value(value)`. This distinguishes binary data from text, including empty data and valid UTF-8, in plugin options, inputs, and results.

Binary libuv results return byte arrays: these include `fs_read`, `random`, UTF-16/WTF-8 conversions, and MAC-address fields in `interface_addresses`. `fs_write` accepts byte arrays and lists of byte buffers. Success/error tuples keep their native order. EOF is an empty byte array; a failed read has a null data slot. Use Bun's file APIs unless file access needs to happen in the editor.

## Use Native Objects

Tree-sitter parsers, trees, nodes, queries, query matches, and LSP clients stay in Neovim. TypeScript gets typed references with asynchronous methods, `get(field)` to read live annotated fields, and `dispose()` to release the reference.

References from `context.vim` expire when the handler settles or its signal is canceled. References from `plugin.vim` last until plugin cleanup and use the plugin signal, even when called from a handler. References can be shared within one loaded plugin, but not across plugins or reloads. To tie a client's cancellation to a handler, get it through `context.vim`.

Releasing a reference does not destroy a shared parser or stop a client. References cannot be returned to Lua as plugin data; return snapshots or other `RpcValue` data.

### Tree-sitter

Inside setup, register a syntax operation:

```ts
plugin.registerFunction("identifierTexts", async (_input, { vim }) => {
  const source = "local value = 7\nreturn value";
  const parser = await vim.treesitter.get_string_parser(source, "lua");
  const trees = await parser.parse();
  const tree = trees && Object.values(trees)[0];
  if (!tree) {
    throw new Error("Parser returned no tree");
  }

  const root = await tree.root();
  const query = await vim.treesitter.query.parse("lua", "(identifier) @name");
  const captures = await query.captureSnapshots(root, source);
  const texts: string[] = [];
  for await (const capture of captures) {
    texts.push(capture.text);
  }

  return texts;
});
```

Install the matching parser in Neovim. Methods such as `node.parent()`, `node.type()`, `node.range()`, and query iterators use their native names. `node.walk({ direction: "ancestors" | "descendants", includeSelf?, namedOnly? })` yields snapshots with `type`, `range`, and `depth`. Descendants follow depth-first source order; ancestors run toward the root. `includeSelf` defaults to false, and the starting node has depth zero. Ranges use Tree-sitter's zero-based rows and byte columns.

`query.captureSnapshots(node, bufferOrSource, { startRow?, endRow? })` yields capture IDs, names, node types, ranges, text, and metadata together, without per-field RPC calls. Text uses capture-local metadata; ranges describe the captured node itself.

Walks, captures, and supported native iterators accept `for await` and `nextBatch({ limit })`. Batches default to 64 items; limits must be integers from 1 through 1,024. A batch returns `{ items, isDone }`. If the last batch is full, another read may be needed to detect the end. `for await` disposes the iterator on completion or early exit. With explicit batching, call `dispose()` to release it.

### LSP Clients

LSP discovery returns live client references:

```ts
plugin.registerFunction("hover", async (_input, { vim, buffer, window }) => {
  const clients = await vim.lsp.get_clients({ bufnr: buffer });
  for (const client of clients) {
    if (!(await client.supports_method("textDocument/hover", buffer))) continue;

    const params = await vim.lsp.util.make_position_params(
      window,
      await client.get("offset_encoding"),
    );
    const [error, result] = await client.request("textDocument/hover", params, buffer);
    return { error, result };
  }

  return null;
});
```

`client.request(method, params, buffer?)` replaces the native handler argument with a promise for `[error, result, context, config]`. Server errors stay structured values in the first slot. The promise rejects if the request cannot start or the client exits before completion. `client.notify(method, params)` returns the native notification result. Cancellation uses the native request ID; late replies are discarded.

Field reads through `client.get(field)` and method calls look up the current client by ID, so calls on stopped clients fail. Incompatible Neovim runtimes fail before sending a request with `LSP client exit callbacks are unavailable`.

## Read Variables and Options

Read and write variables and options asynchronously:

```ts
await vim.g.set("bunvim_enabled", true);
await vim.b.at(context.buffer).set("analysis", { words: 12 });
const analysis = await vim.b.at(context.buffer).get("analysis");
await vim.b.at(context.buffer).delete("analysis");
await vim.bo.at(context.buffer).set("shiftwidth", 2);
await vim.wo.at(context.window).local.set("number", true);
await vim.opt.append("path", ["src"]);
const paths = await vim.opt.get("path");
```

This example uses `const { vim } = context` inside a handler. `g`, `b`, `w`, `t`, `v`, and `env` provide `get`, `set`, and `delete`. Neovim rejects invalid names and writes to read-only values. Select a buffer, window, or tab with `b.at(buffer)`, `w.at(window)`, or `t.at(tabpage)`. Missing variables and environment values return null. Environment writes accept strings.

`o`, `go`, `bo`, and `wo` provide `get` and `set` with Neovim's option behavior. Use `bo.at(buffer)` or `wo.at(window)` to target a handle. `wo.at(window).local` changes the window-local value without changing its global default. `opt`, `opt_local`, and `opt_global` also provide `append`, `prepend`, and `remove`. Neovim converts lists, maps, and flags and validates option names and values at runtime.

Unqualified access and handle zero use the editor context current at execution time. Use `.at(...)` with `context.buffer` or `context.window` if the user could change focus during an await. Calls check the context's signal before sending and after receiving, but a sequence of calls is not atomic.

## Synchronous Results

Handlers may be `async` even when Neovim needs their result synchronously:

```ts
plugin.registerKeymap({ mode: "n", keys: "<Plug>(InsertLineLength)", expr: true }, async (context) => {
  const line: unknown = await context.nvim.request("nvim_get_current_line");
  if (typeof line !== "string") {
    throw new Error("Expected the current line");
  }

  return `A${line.length}\u001b`;
});

plugin.registerCommand({
  name: "ChooseMode",
  nargs: 1,
  complete: ({ argLead }) => ["trim", "keep"].filter((mode) => mode.startsWith(argLead)),
}, async (context) => {
  await context.nvim.outWrite(`Selected ${context.args}\n`);
});

plugin.registerAutocmd({ event: "BufWritePre", execution: "sync" }, async (context) => {
  const snapshot = await readBuffer(context);
  await replaceBuffer(context, snapshot, snapshot.lines.map((line) => line.trimEnd()));
});
```

Put these examples inside setup, using the `readBuffer`/`replaceBuffer` imports shown below. Completion receives `argLead`, `cmdLine`, and `cursorPos` alongside the invocation context, and returns `string[]`. Expression mappings return a string of keys; Neovim's textlock prevents them from editing the buffer directly. A synchronous completion callback does not make the command body synchronous.

Lua can call a named function through `call_sync(name, method, { input = value, timeout_ms = 1000 })`. The plugin must already be loaded. This returns the value or raises an error. Nested editor calls are supported, with a maximum synchronous nesting depth of 32.

The default synchronous deadline is 1,000 ms. Neovim waits for the result, so avoid network requests and CPU-heavy work in these hooks. On timeout, an editor-side watchdog kills the shared host even if Bun's event loop is blocked. This stops all plugins in the host. Setup and unload timeouts also kill the host.

## Read and Edit a Buffer

Inside a plugin located at `examples/my-plugin/index.ts`:

```ts
import { readBuffer, replaceBuffer, type PluginSetup } from "../../src";

const setup: PluginSetup = (plugin) => {
  plugin.registerCommand({ name: "TrimTrailingSpace" }, async (context) => {
    const snapshot = await readBuffer(context);
    const lines = snapshot.lines.map((line) => line.trimEnd());
    await replaceBuffer(context, snapshot, lines);
  });
};

export default setup;
```

`readBuffer(context, { start, end })` uses zero-based line indexes and an exclusive end. The defaults, zero and minus one, select the whole buffer. The snapshot contains the buffer ID, changed tick, range, and lines.

`replaceBuffer` throws if the buffer was unloaded or changed since the snapshot. Report the error or start again with a new snapshot; do not overwrite the user's newer text.

Use `context.vim` for other editor operations. The lower-level `context.nvim` client is also available; see its [API documentation](https://neovim.io/node-client/) for buffers, windows, options, variables, commands, and raw requests. Use one `executeLua` call for operations that must observe the same editor state.

## Subscribe to Buffer Changes

Subscribe to receive buffer changes in order. Bunvim manages the editor-side attachment and plugin cleanup:

```ts
const subscription = plugin.subscribeBuffer(
  { buffer, maxQueued: 256 },
  async (event, { signal }) => {
    signal.throwIfAborted();
    if (event.type === "snapshot") {
      console.log("Initial lines", event.lines.length);
    } else if (event.type === "lines") {
      console.log("Changed range", event.firstLine, event.lastLine, event.lines);
    }
  },
);
await subscription.ready;
```

Here `buffer` must be a loaded buffer ID; zero selects the current buffer when subscribing. `ready` resolves after attachment and snapshot synchronization, but handlers may still be running. The event types are:

- `snapshot`: the initial buffer contents, with `buffer`, `changedtick`, and `lines`.
- `lines` or `changedtick`: later updates. Line events contain zero-based `firstLine`, exclusive `lastLine`, replacement lines, the changed tick, and `hasMore` for multipart updates. Changed-tick events carry no lines. Display-only updates without a changed tick are ignored.
- `detach`: ends delivery when the native attachment closes.

Each subscription waits for its handler before delivering the next event. Its queue holds at most `maxQueued` pending events (default 256). Overflow ends the subscription; events are never coalesced. Subscribe again for a new snapshot after overflow or native detach.

`closed` resolves to `{ reason: "disposed" | "detached" | "overflow" }` or `{ reason: "error", error }`. Logs identify the plugin and buffer for handler errors. `dispose()` stops delivery, aborts the subscription signal, and waits for attachment cleanup. It does not wait for the handler to finish, so a handler can await its own subscription's disposal.

Unload and setup rollback wait for in-flight handlers before plugin cleanup, subject to their configured deadlines. Multiple plugins can subscribe to one buffer; stopping one leaves the others attached.

## Invocation Context

All handlers receive:

- `vim`: typed asynchronous Neovim calls using this invocation's signal.
- `nvim`: the shared native client.
- `signal`: cancellation for this invocation.
- `buffer`: the initiating buffer ID.
- `window`: the initiating window ID.
- `cwd`: the working directory captured at invocation.

Command handlers also receive Neovim's `args`, `fargs`, `bang`, `line1`, `line2`, `range`, `count`, and `reg`. Event handlers receive `event`, `match`, `file`, and unknown `data`. Event buffer context comes from the event, which may differ from the current buffer.

Function inputs and plugin options are unknown; validate them before use. Return finite JSON-like values or `Uint8Array`, including nested bytes. Thrown errors reach the Lua caller. Returning `undefined` or nothing produces no Lua result.

Asynchronous calls dispatch directly to the host without a per-plugin concurrency limit or event coalescing. Handlers may overlap. CPU-heavy async handlers delay other Bun plugins while Neovim stays responsive. In synchronous hooks, that work also blocks Neovim. Use a worker for CPU-heavy work.

## Cancellation and Resource Lifetime

Pass the invocation signal to cancellable I/O, such as `fetch(url, { signal: context.signal })`. Check `signal.throwIfAborted()` before applying delayed work. Bunvim's buffer-edit helper checks it before sending an edit.

Canceling a Lua call completes its callback with `"Request canceled"` and signals its handler. Deadlines use `"Request timed out"`. Late results are discarded. A running call remains pending until the handler settles, even if it ignores cancellation. Cancellation cannot interrupt JavaScript or roll back editor operations already sent.

The `vim` API checks the signal before calls and after replies. Canceling a completion wait removes its listener and discards late replies. It closes one-shot timers, cancels LSP requests, requests libuv cancellation, and kills processes started through the completion adapter. Libuv work already running may finish, and an overridden UI may stay visible until its implementation closes it.

Bunvim closes file descriptors from canceled `fs_open` or `fs_mkstemp` calls if TypeScript has not accepted the result. After acceptance, the caller must close the descriptor. Host shutdown releases pending adapter resources. Cancellation cannot undo completed filesystem changes.

Use the plugin-lifetime signal for ongoing plugin resources and `onDispose` for cleanup:

```ts
plugin.onDispose(() => {
  clearInterval(timer);
});
```

This example assumes the plugin created a timer with `setInterval`. Bunvim cleans up SDK buffer subscriptions automatically. Unload rejects new work, aborts and waits for running handlers, then runs disposal callbacks in reverse registration order. It collects cleanup errors. If a handler or disposal never settles, the unload deadline kills the host, so later cleanup callbacks may not run.

Errors keep their stack and identify the plugin and operation. Console output goes to `:BunvimLog` with the same labels, including across awaits. Standard output carries RPC traffic; do not write to it, including from workers.

Use `parentPort` for worker messages and await termination in `finally`, including on cancellation. Bun runs TypeScript workers directly and supports awaiting termination through [`node:worker_threads`](https://bun.com/reference/node/worker_threads/Worker/terminate).

## Lua Lifecycle API

`setup` accepts a `plugins` map. Each plugin entry requires a `path` and accepts optional `options`; paths are expanded and resolved during configuration. It also accepts `on_ready` and these host settings:

- `bun`: executable name or path, default `"bun"`.
- `startup_timeout_ms`: handshake deadline, default 5,000 ms.
- `setup_timeout_ms`: per-plugin setup deadline, default 5,000 ms.
- `unload_timeout_ms`: per-plugin unload deadline, default 1,000 ms.
- `shutdown_timeout_ms`: process-exit deadline, default 1,000 ms.
- `sync_timeout_ms`: synchronous-call deadline, default 1,000 ms.

Load a plugin at runtime:

```lua
require("bunvim").load("my-plugin", {
  path = "/absolute/path/to/my-plugin/index.ts",
  options = { greeting = "Hello" },
  on_complete = function(err)
    if err then vim.notify(err, vim.log.levels.ERROR) end
  end,
})
```

`unload(name, { on_complete = callback })` disposes one plugin. `stop({ on_complete = callback })` stops the host but keeps the configured plugin list. `start({ on_ready = callback })` or `restart({ on_ready = callback })` loads that list.

Stop the host before calling `setup` again. Setup merges supplied plugin entries into the configured list; unload an entry to remove it. A failed plugin remains visible in `status().plugins` until unloaded or restarted.

`status()` returns the host state, channel, process ID, pending count, and plugin statuses. Pending includes canceled invocations that have not settled. `logs()` returns a copy of recent stderr lines.

## Development Loop

After editing TypeScript, run `:BunvimRestart`. It starts a fresh Bun process and reloads imported helpers too.

From the Bunvim directory, run `bun run typecheck` and `bun test`. Tests that run Neovim live under `tests/`; SDK unit tests live beside their source. Keep plugin-specific tests in the plugin's directory.

### Update Vim Types

When updating Neovim, regenerate the SDK declarations with `bun run generate:vim-types`. Generation requires `nvim` and `lua-language-server` on `PATH`; running plugins does not require Lua Language Server.

`src/vim/generated/vim-functions.json` records the target Neovim version. `src/vim/generated/vim-coverage.json` lists supported paths, unsupported paths with reasons, and unexpected omissions. Generation fails on unexpected omissions.

Run `bun run check:vim-types` to check declarations, runtime metadata, and coverage against the installed tools without rewriting files. If they are stale, the check fails and names the files to regenerate.

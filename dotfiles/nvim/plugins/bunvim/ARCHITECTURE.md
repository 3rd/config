# Bunvim Architecture

Bunvim runs TypeScript plugins in one persistent Bun process per Neovim instance. Lua controls that process and sends calls over Neovim's RPC job channel. Bun loads plugins and runs their handlers.

## Modules

`plugin/bunvim.lua` initializes the Lua API and management commands. With no configured plugins it does not start Bun.

### Lua Host

- `lua/bunvim/init.lua`: public Lua API, process lifecycle, and configured plugin activations.
- `lua/bunvim/host/configuration.lua`: defaults and validation for plugin paths and options.
- `lua/bunvim/host/commands.lua`: management commands, using the public Lua API.
- `lua/bunvim/host/requests.lua`: request IDs, callbacks, deadlines, cancellation, and synchronous nesting. Reads process and plugin state from `init.lua`.
- `lua/bunvim/host/registrations.lua`: installation and removal of commands, keymaps, and autocommands.

### Bun Host

- `src/index.ts`: public SDK exports. `src/types.ts` defines the SDK contract.
- `src/runner.ts`: Bun entrypoint, native client connection, synchronous response ordering, and process exit.
- `src/host/plugin-host.ts`: message dispatch and active calls.
- `src/host/plugin-activation.ts`: setup, the plugin's abort signal and Vim scope, subscription drain, and disposal callbacks.
- `src/host/plugin-registrations.ts`: handler IDs, registration acknowledgments, and setup readiness.
- `src/host/diagnostics.ts`: stderr logging and plugin/operation context across awaits.
- `src/rpc/protocol.ts`: invocation metadata validation and result serialization checks. Plugins validate their own input and options.

### Editor API

The `neovim` package provides MessagePack framing and the low-level `nvim` client. The typed `vim` API uses that connection to call Lua. A recursive proxy resolves function paths; generated metadata describes their arguments, results, and callbacks.

- `src/vim/facade.ts`: the `vim` proxy, RPC calls, and callback listeners tied to an abort signal.
- `lua/bunvim/vim/init.lua`: synchronous dispatch and channel/scope cleanup.
- `src/vim/native-references.ts`: host-side reference identity, encoding, access, and invalidation.
- `src/vim/metadata.ts`: validation of generated function and native-class metadata.
- `lua/bunvim/vim/callbacks.lua`: completion callbacks, result conversion, cancellation, and LSP exit listeners.
- `lua/bunvim/vim/native.lua`: native function lookup, references, batched iterators, Tree-sitter walks, and capture snapshots.
- `src/rpc/value-codec.ts` and `lua/bunvim/rpc/codec.lua`: tagged encoding for plugin data and Vim calls. The Lua codec also packs result tuples and unpacks arguments.
- `src/vim/scoped-state.ts` and `lua/bunvim/vim/scoped-state.lua`: variable and option access through Neovim's native state objects.
- `src/buffers/editor.ts` and `lua/bunvim/editor.lua`: atomic buffer snapshots and edits guarded by a changed-tick check.
- `src/buffers/attachments.ts`: shared native buffer attachments and event listeners.
- `src/buffers/subscriptions.ts`: snapshot synchronization, per-subscriber event queues, and handler drain during cleanup.

### Generated Types and Tests

`scripts/vim-types/` reads LuaCATS metadata and discovers native functions to generate three files:

- `src/vim/generated/vim-types.ts`: TypeScript declarations.
- `src/vim/generated/vim-functions.json`: return counts, callback positions and lifecycle contracts, constants, unsupported-call reasons, and the target Neovim version.
- `src/vim/generated/vim-coverage.json`: supported, unsupported, and omitted callable paths.

In the generator, `vim-inventory.ts` validates discovered functions and selects Lua definitions. `vim-namespace.ts` assembles and renders namespaces. `generate-vim-types.ts` coordinates these with signature, type, and native-class rendering.

Unit tests live beside their modules. Cross-process tests and fixtures live in `tests/host/`, `tests/rpc/`, `tests/buffers/`, and `tests/vim/`, using `tests/run-editor.ts` for isolated Neovim instances. Development and example plugins keep their tests in their own directories.

## Invocation

A Lua call captures its buffer, window, and working directory, then sends an RPC notification when the host is running. Commands, ordinary mappings, and asynchronous events follow this path using their handler IDs. Calls made during host startup are sent once the transport is ready. Asynchronous handlers may overlap without a host-imposed concurrency limit.

The host waits for setup if needed, creates the call's abort signal and Vim scope, validates the origin, and runs the handler. It releases the scope before settling the call, then notifies Lua of the result. The codecs distinguish arrays, objects, bytes, and native references with tags that cannot collide with user data. See [supported values](docs/PLUGIN_DEVELOPMENT.md#values-and-types) for serialization rules.

Lua removes a completed request before scheduling its callback. Cancellation removes unsent work immediately. For sent work, it completes the callback immediately but tracks the request until the host confirms settlement. Late results cannot invoke the callback again. Lua ignores responses from an old channel.

## Registration and Cleanup

Registrations install when created, during setup or later. Setup becomes ready after Lua acknowledges all editor installations. Function registrations stay in the Bun host. Installation and removal acknowledgments back the SDK's `ready` and `dispose()` promises.

Registrations cannot overwrite existing commands or mappings. Cleanup leaves user replacements intact. Failed installations remove any resources they created; failed setup removes the activation's resources and runs disposal callbacks in reverse order. Each installation and removal carries an increasing activation generation and a registration ID, so delayed work cannot remove a replacement plugin's registrations.

Unload rejects new calls and registrations, removes editor entrypoints, aborts the plugin signal and active calls, waits for handlers to settle, and runs disposal callbacks. The plugin name stays reserved until unload finishes. Plugins must clean up resources they create through direct client calls.

Buffer subscriptions share native attachments but have separate queues. Each subscriber receives an atomic snapshot, then changes with later ticks in native multipart order. A full queue ends that subscription with `overflow`. Subscription disposal stops delivery and waits for attachment removal. Activation disposal also waits for in-flight handlers before user cleanup, subject to the unload deadline. Keeping these waits separate lets a handler dispose its own subscription.

Each Vim facade has a reference scope within its plugin activation. References can cross facades in that activation but expire with their creating facade: handler references end when the handler settles, and setup references last until plugin cleanup. Releasing a reference does not destroy a borrowed parser or stop a shared LSP client. Channel and scope cleanup cancel pending callbacks before releasing references.

LSP operations look up live clients by ID. Targeted requests add and remove an exit listener in `_on_exit_cbs` because unattached clients do not provide buffer-detach events. Bunvim checks this internal hook before starting a request and rejects incompatible runtimes.

## Synchronous Hooks

Expression mappings, custom command completion, synchronous autocommands, and `call_sync` use `vim.rpcrequest`. The host awaits the handler and replies with its serialized result. Neovim can handle nested editor API requests while waiting. The runner returns nested responses in reverse request order, and Lua limits nesting to 32.

An editor-side fast libuv timer records the host PID and kills it on timeout, even if JavaScript is blocked or scheduled Lua callbacks cannot run. Neovim's textlock still applies: expression handlers return keys and cannot edit the buffer directly. Synchronous pre-write handlers can finish edits before the write proceeds.

## Host Lifecycle

The host can be idle, starting, running, stopping, or failed. Running means the transport is ready; plugins may still be loading. The setup/start callback completes after the startup plugin batch settles.

Startup has a handshake deadline. Each setup and unload has its own deadline. A setup, unload, or synchronous timeout kills the shared host because Bunvim cannot forcibly cancel one plugin's JavaScript in isolation. Stop removes registrations and fails pending calls immediately, then requests cleanup. The shutdown deadline kills a host that does not exit.

Unexpected exit clears registrations and completes pending callbacks. The next Lua function call can start the configured plugins again. Restart waits for the old process to exit, then starts a new process with an empty module cache, including transitive imports.

When Neovim exits, it requests shutdown and waits up to the shutdown deadline. There is no idle polling timer. Async calls create timers only for requested deadlines; synchronous hooks always have a watchdog.

## Editor Consistency

Handlers receive the initiating buffer and window. They should not assume that the current buffer still matches after an await.

`readBuffer` fetches a range and its changed tick in one editor operation. `replaceBuffer` checks that tick and writes the captured range in one Lua operation. If the buffer changed or was unloaded, the edit fails rather than overwriting newer work. It also checks the invocation signal before submitting the edit.

This check protects the snapshot-based edit, not a sequence of direct Neovim client calls.

## Benchmarks

The benchmark waits for Lua calls to return, compares native notification round trips, and runs a fixture-only uppercase command. It starts three host processes in sequence. Each run has 100 warmups, 1,000 measured calls, 100 command-driven 1,000-line edits, and 1,000 events. It also measures cold startup, memory, idle CPU ticks, and shutdown. Benchmark operations live in `benchmarks/` and do not depend on the example plugins.

The sustained variant runs four plugins for 60 seconds, sending eight calls and eight events every 10 ms. It also runs ten 500 ms CPU-worker jobs, synchronous 1,000-line pre-write edits, and 110 load/unload cycles (ten warmup, 100 measured). It checks event counts and drained queues, measures latency while workers run, and records memory after benchmark-only garbage collection.

`bun run benchmark` and `bun run benchmark --sustained` print samples and source hashes as JSON.

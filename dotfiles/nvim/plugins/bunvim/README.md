# Bunvim

Write Neovim plugins in TypeScript and run them directly with Bun.

Plugins share one Bun process per editor. They can keep state, register commands, keymaps, autocommands, and functions, and call Neovim through a typed, asynchronous `vim` API.

## Get Started

This Neovim configuration loads Bunvim as a local plugin. Install its dependencies:

```sh
cd plugins/bunvim
bun install --frozen-lockfile
```

Restart Neovim, then run:

```vim
:BunvimDemo
:PickColorscheme
```

Wait for the demo to load before running `:PickColorscheme`; check `:BunvimStatus` for its status. Move through the list to preview themes, press Enter to keep one, or Escape to restore the previous colors.

Bunvim starts when a plugin is configured or loaded, or when you run `:BunvimStart`. The demo loads all four [examples](#examples). None assigns editing keys.

Tested with Bun 1.4.0 and Neovim 0.13.0-nightly+28d641b on Linux. The host uses `neovim` 4.10.1.

## Configure a Plugin

```lua
require("bunvim").setup({
  plugins = {
    ["format-json"] = {
      path = vim.fn.stdpath("config") .. "/plugins/bunvim/examples/format-json/index.ts",
    },
  },
  on_ready = function(err)
    if err then vim.notify(err, vim.log.levels.ERROR) end
  end,
})
```

Each entry requires a `path` and accepts optional `options`. Bunvim resolves paths during configuration. Options arrive as `unknown` in TypeScript; validate them in setup. Stop the host before reconfiguring it. See the [configuration reference](docs/PLUGIN_DEVELOPMENT.md#lua-lifecycle-api) for timeouts.

## Write a Plugin

For a plugin inside `examples/my-plugin/index.ts`:

```ts
import type { PluginSetup } from "../../src";

const setup: PluginSetup = (plugin) => {
  let count = 0;

  plugin.registerFunction("increment", () => ++count);
  plugin.registerCommand({ name: "CountVisits" }, async ({ nvim }) => {
    await nvim.outWrite(`Visits: ${++count}\n`);
  });
};

export default setup;
```

Setup waits for its registrations and removes them if it fails. For registrations added after setup, await the returned handle's `ready` promise before using them. See [registration handles](docs/PLUGIN_DEVELOPMENT.md#register-entrypoints) for removal and cleanup.

For a plugin outside this repository, add this local Bunvim package as a dependency and import from `"bunvim"`.

Use `vim` in setup and handlers for calls such as `await vim.api.nvim_get_current_buf()`. The lower-level `nvim` client is also available. The [plugin guide](docs/PLUGIN_DEVELOPMENT.md) covers [Vim calls](docs/PLUGIN_DEVELOPMENT.md#use-the-vim-api), [Tree-sitter and LSP objects](docs/PLUGIN_DEVELOPMENT.md#use-native-objects), [variables and options](docs/PLUGIN_DEVELOPMENT.md#read-variables-and-options), and [buffer subscriptions](docs/PLUGIN_DEVELOPMENT.md#subscribe-to-buffer-changes).

## Examples

Load all four with `:BunvimDemo`, or configure any one by its `index.ts` path:

- [Copy file path](examples/copy-path/index.ts): `:CopyFilePath` copies the current file's absolute path to the `+` clipboard register. Requires a named buffer and a Neovim clipboard provider. Uses `vim.api.nvim_buf_get_name` and `vim.fn.setreg`.
- [Colorscheme picker](examples/colorscheme-picker/index.ts): `:PickColorscheme` opens a floating list of installed themes. Move with `j`/`k` or the arrow keys to preview each theme, press Enter to keep it, or Escape/`q` to restore the previous colors and custom highlights. Closing the picker or unloading the plugin also restores them. Uses Neovim's window API, buffer-local keymaps, and cursor-movement events.
- [Format JSON](examples/format-json/index.ts): `:FormatJSON` formats the whole buffer with two-space indentation. Use `:'<,'>FormatJSON` or `:2,5FormatJSON` for a line range containing complete JSON. `readBuffer` and `replaceBuffer` keep edits tied to the initiating buffer and reject stale edits. Invalid JSON leaves the buffer unchanged; successful edits support undo and do not save the file. Parsing uses JavaScript's JSON rules, including its number precision.
- [TODO list](examples/todo-list/index.ts): `:TodoList` creates a quickfix list with one entry per line containing a whole-word, uppercase `TODO` or `FIXME`. It scans only the current buffer, opens the list when matches exist, and reports empty results. Select an entry with Enter, or use `:cnext`. Uses `readBuffer`, `vim.fn.setqflist`, and `vim.cmd.copen`.

## Call from Lua

```lua
local request = require("bunvim").call("my-plugin", "increment", {
  on_complete = function(err, count)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end

    print("Visits: " .. count)
  end,
})
```

Calls return immediately. Pass plugin data as `input` and set a positive `timeout_ms` for a deadline. Call `request.cancel()` to cancel. A call rejected because the plugin or host is unavailable returns no handle. Callbacks receive the error first and the result second; without one, errors appear through `vim.notify`.

When Neovim must wait for a result, use `call_sync(name, method, { input = value, timeout_ms = 1000 })`. The plugin must already be loaded. The call returns the result or raises an error. See [synchronous handlers](docs/PLUGIN_DEVELOPMENT.md#synchronous-results) for expression mappings, completion, and pre-write edits.

## Manage the Host

- `:BunvimStatus`: host state, process ID, pending count, and plugin status.
- `:BunvimLog`: recent stderr output, labeled by plugin and operation.
- `:BunvimStart`: start the host and load configured plugins.
- `:BunvimStop`: abort pending work and remove plugin registrations.
- `:BunvimRestart`: stop the old process, then load a fresh process and all configured plugins.
- `:BunvimCancel {id}`: cancel an outstanding invocation.

Restart reloads imported dependencies as well as plugin entrypoints. Unloading and loading in the same host creates fresh plugin state but retains Bun's module cache.

## Validate

From this directory:

```sh
bun run typecheck
bun test
bun run benchmark
bun run benchmark --sustained
```

Integration tests run isolated Neovim processes. The Linux benchmarks measure RPC latency, editing, event delivery, startup, and resource use. See [benchmark details](ARCHITECTURE.md#benchmarks) for the workloads and output. Run benchmarks outside a sandbox or agent-injected file interception; they reject inherited seccomp filters or `LD_PRELOAD`.

## Limits

Plugins are trusted local code. Synchronous handlers block Neovim, so keep them short. A setup, unload, or synchronous timeout kills the shared host and stops every plugin in it. Start or restart the host to recover.

Bunvim cleans up SDK registrations. Plugins must clean up resources they create directly. Cancellation is cooperative and cannot undo an editor operation already sent. See [cancellation and cleanup](docs/PLUGIN_DEVELOPMENT.md#cancellation-and-resource-lifetime) before adding delayed work or background resources.

See [architecture](ARCHITECTURE.md) for ownership and lifecycle details.

# Condom

**Condom** is a Linux-first developer safety wrapper. It runs risky tools inside a policy boundary, keeps credentials on the host, and records what happened.

Use it in two modes:

| Mode | Command | What happens |
| --- | --- | --- |
| Run | `condom run -- <command>` | Executes the command through Fence, Landlock, seccomp, filesystem mediation, and the local proxy. |
| Review | `condom review -- <command>` | Captures project writes in a temporary overlay, then asks you to approve or discard them. |

## Quick Start

```bash
make install
condom init
direnv allow
condom doctor
condom run -- npm test
condom review -- npm update
```

`condom init` writes:

| Path | Purpose |
| --- | --- |
| `.condom/config.toml` | Project policy and defaults |
| `.condom/bin/` | Generated shims for configured tools |
| `.envrc` | Adds `.condom/bin` to `PATH` through direnv |

## Commands

| Command | Purpose |
| --- | --- |
| `condom init [--root PATH] [--force]` | Initialize project config and shims. |
| `condom doctor [--json]` | Check project, helper, proxy, and capture readiness. |
| `condom status [--json]` | Show project state, approvals, events, and proxy status. |
| `condom run -- <command>` | Run a command with enforcement. |
| `condom review -- <command>` | Run a command, capture writes, and approve or discard them. |
| `condom allow add <kind> <subject>` | Add a temporary allow or deny decision. |
| `condom allow ls [--json]` | List approvals. |
| `condom allow rm <id>` | Remove an approval. |
| `condom env allow <name>` | Pass a host environment variable into runs. |
| `condom env deny <name>` | Block an environment variable even if otherwise allowed. |
| `condom env ls [--json]` | List environment passthrough policy. |
| `condom env rm <name>` | Remove an environment rule. |
| `condom events [--json]` | Show recent structured events. |

## Policy

Project policy lives in `.condom/config.toml`.

Common keys:

| Key | Meaning |
| --- | --- |
| `filesystem.allowRead` | Host paths the command may read. |
| `filesystem.allowWrite` | Host paths the command may write. |
| `filesystem.allowExecute` | Host paths the command may execute. |
| `filesystem.denyRead` | Host paths that are always denied. |
| `filesystem.denyWrite` | Host paths that are always denied for writes. |
| `filesystem.redactRead` | Host files served as deterministic redacted placeholders. |
| `exec.allow` | Command patterns reserved for spawned-command allow policy. |
| `exec.deny` | Command patterns reserved for spawned-command deny policy. |
| `environment.allow` | Exact host environment variable names passed into runs. |
| `environment.deny` | Exact host environment variable names blocked from runs. |
| `network.denyMetadata` | Hard-deny cloud metadata destinations when enabled. |
| `network.denyPrivate` | Hard-deny private/internal IP destinations when enabled. |
| `proxy.adapters` | Enabled proxy adapters, such as npm, pip, Cargo, Go, and generic HTTP. |
| `proxy.allowedHosts` | Proxy destinations allowed without prompting. |
| `proxy.cacheTtlSeconds` | Freshness window for unauthenticated cached GET responses. |
| `proxy.npmRegistry` | Optional npm registry written into generated npm config. |
| `proxy.npmIgnoreScripts` | Optional npm `ignore-scripts=true` hardening. |
| `proxy.pipIndexUrl` | Optional pip index URL written into generated pip config. |
| `proxy.pipNoInput` | Optional pip `no-input=true` hardening. |
| `proxy.pipDisableVersionCheck` | Optional pip version-check suppression. |
| `proxy.cargoGitFetchWithCli` | Optional Cargo `git-fetch-with-cli` setting. |
| `proxy.goProxy` | Optional Go `GOPROXY` value. |
| `proxy.goSumdb` | Optional Go `GOSUMDB` value. |
| `proxy.goVcs` | Optional Go `GOVCS` value. |
| `proxy.goAuth` | Optional Go `GOAUTH` value. |
| `review.fileRules` | Path rules for review visibility and default selection. |

Environment allow and deny entries are exact names. Deny wins; runtime-owned values such as `HOME`, `PATH`, `TMPDIR`, and `CONDOM_*` are pinned by condom. The command passed to `condom run --` or `condom review --` is the user-approved entrypoint; `exec.*` does not deny that entrypoint.

`condom run` and `condom review` always route network access through Condom's proxy policy system.

There is no built-in filesystem deny/hide list for sensitive host paths, and there is no built-in proxy allow-list, but condom still protects its own project/runtime config, shims, and cache paths. Other host filesystem and proxy access is resolved through policy, stored approvals, or the approval prompt. Review may still flag high-risk changes, but those flags do not grant, hide, or deny access.

Review file rules match review-relative paths with `*` and `**`. Hidden files stay applyable when selected, but are omitted from the review tree. For package upgrade flows that rewrite Git bookkeeping, keep hooks and config visible while default-selecting noisy internals:

```toml
[[review.fileRules]]
match = "**/.git/index"
visibility = "hidden"
defaultSelected = true

[[review.fileRules]]
match = "**/.git/index.lock"
visibility = "hidden"
defaultSelected = true

[[review.fileRules]]
match = "**/.git/FETCH_HEAD"
visibility = "hidden"
defaultSelected = true

[[review.fileRules]]
match = "**/.git/logs/**"
visibility = "hidden"
defaultSelected = true

[[review.fileRules]]
match = "**/.git/objects/**"
visibility = "hidden"
defaultSelected = true

[[review.fileRules]]
match = "**/.git/refs/**"
visibility = "hidden"
defaultSelected = true
```

## Runtime Behavior

`run` keeps generated runtime files under the project runtime area and state directory. `review` uses a temporary runtime directory and mounts only the minimal `.condom` surface needed by registry proxies and helpers.

Condom's persisted approvals and events use `CONDOM_STATE_HOME` when set, or `$HOME/.local/state` by default; runtime `XDG_STATE_HOME` values are treated as application environment, not Condom state.

## Proxy and Credentials

The local proxy handles registry and generic HTTP(S) traffic. Tool adapters materialize runtime proxy/cache config for npm, pip, Cargo, and Go without receiving host credentials. Registry choices and package-manager hardening are configured explicitly in `.condom/config.toml`.

Credential sources:

| Source | Config |
| --- | --- |
| Host env | `CONDOM_CREDENTIAL_<HOST>` |
| Host file | `proxy.credentialFile` |
| Host command | `proxy.credentialCommand` |
| pass | `proxy.credentialPassPrefix` |
| Secret Service | `proxy.credentialSecretService` |
| Helper | `proxy.credentialSource = "helper"` |

Credentials are injected only inside the host-side proxy and are not passed to the wrapped process.

## Helper and NixOS

`condom-helper` prepares and runs sandboxes, authorizes filesystem access, and serves credentials. `condom doctor` checks helper protocol compatibility and advertised capabilities.

The NixOS module can install:

| Feature | Purpose |
| --- | --- |
| Sandbox tools | `fence`, `bubblewrap`, and capture backend packages |
| Helper socket | A restricted socket-activated helper service |
| Transparent proxy routing | nftables and policy routing for intercepted TCP |
| Capability wrapper | `/run/wrappers/bin/condom-tproxy` for `IP_TRANSPARENT` |

## Development

Use the project flake shell through `make`.

| Command | Purpose |
| --- | --- |
| `make build` | Build release binaries. |
| `make install` | Install `condom`, `condom-helper`, and `condom-approval` to `$HOME/.local/bin`. |
| `make uninstall` | Remove installed binaries from `BINDIR`. |
| `make fmt-check` | Check Rust formatting. |
| `make check` | Run `cargo check`. |
| `make clippy` | Run Clippy with warnings denied. |
| `make test` | Run Rust tests through `nix develop`. |
| `make verify` | Run format, check, clippy, and tests. |

Review integration tests require `/dev/fuse` and `fuse-overlayfs`.

## See Also

- [modules/condom.nix](modules/condom.nix)

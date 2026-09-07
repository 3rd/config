# Grok Bot

A Home Manager package for the Grok Bot desktop application, built from the upstream Linux `.deb`.

- [`package.nix`](./package.nix) owns the version, build ID, source URL, source hash, runtime
  dependencies, install layout, and wrapper.
- [`default.nix`](./default.nix) adds the package to `home.packages`.

Import `default.nix` from the host configuration that should have the application. It is deliberately
not part of a shared role, flake output, or overlay, because only some machines want it.

## Trust boundary

The application is a closed-source Electron binary. The packaging here is auditable; the bundled
application, Electron runtime, and native modules are not.

What the package does to limit the remaining surface:

- Fetches one versioned `.deb` from `downloads.cursor.com`, the domain linked from the
  [Grok Bot announcement](https://x.ai/news/introducing-grok-bot).
- Pins the bytes with a SHA-256 hash, so a changed artifact fails before installation.
- Extracts the Debian data archive with `dpkg-deb -x`, and never runs `postinst`, `postrm`, or any
  other maintainer script.
- Depends on no third-party Grok Bot flake or packaging repository.

The artifact carries no standalone Debian signature member, so HTTPS transport and the reviewed
fixed hash are the only authenticity controls. Always compute the hash locally from the bytes you
downloaded.

## What the derivation expects

The upstream archive must contain:

- `opt/Grok Bot/grok-bot`
- `opt/Grok Bot/chrome-sandbox`
- `usr/share/applications/grok-bot.desktop`
- `usr/share/icons/hicolor/*/apps/grok-bot.png`

The install phase uses exact paths and `--replace-fail` on purpose: an upstream rename or layout
change should break the build so the new archive gets reviewed before the package changes.

`autoPatchelfHook` patches the executable and native modules. `runtimeDependencies` keeps the
libraries Chromium loads through `dlopen()` reachable via RPATH. `wrapGAppsHook3` supplies the GTK
environment.

The wrapper adds `xdg-utils` to `PATH` and sets `CHROME_DESKTOP=grok-bot.desktop`. The upstream
desktop entry registers the `grokbot://` and older `sand://` handlers, and that variable gives
Electron the right desktop ID when it calls `xdg-settings`.

This module does not enable `xdg.mimeApps`. In this repository,
[`desktop/mime.nix`](../../desktop/mime.nix) already owns
`~/.local/share/applications/mimeapps.list`, and Home Manager's MIME module would become a second
writer for the same file. Extend the existing owner if protocol defaults need declarative
management.

## Chromium sandbox

The package deletes `chrome-sandbox`, because the Nix store cannot carry the setuid-root bit the
helper needs. It does not pass `--no-sandbox`; Chromium falls back to its user-namespace sandbox,
which requires unprivileged user namespaces on the host:

```bash
unshare --user --map-root-user true
```

If that fails, the renderer will not start under the namespace sandbox. Fix the host setting rather
than adding `--no-sandbox`. Note that a sandboxed shell can reject the syscall even when the host
allows it, so confirm the probe outside any container or command sandbox.

The AppArmor profile shipped in the archive is unconfined and adds no isolation. If AppArmor is
enforcing on your machine (`cat /sys/module/apparmor/parameters/enabled`), inspect the profile in the
current archive before adding system policy.

Don't add `--no-sandbox` because an older release needed it. The `0.24.0`-era renderer crash no
longer reproduces on current versions. Diagnose a renderer failure against the current artifact and
host namespace support first.

## Upgrading

The application cannot update an immutable Nix store installation. Upgrading means changing three
pins in `package.nix`: `version`, `buildId`, and `hash`.

1. Query the stable update manifest.

   ```bash
   curl -fsSL \
     'https://api2.cursor.sh/updates/api/update/linux-x64/sand/0.0.0/07d67027-2556-4c0e-9fd9-e0bde18922ca/stable' |
     jq
   ```

   Read the version from `version` and the build ID from the path segment right after `stable/` in
   `url`. The feed returns an AppImage URL, and its `sha256hash` describes the AppImage, not the
   Debian package. Stop here if the version matches `package.nix`.

2. Download the `.deb` for that exact version and build ID.

   ```bash
   version="NEW_VERSION"
   build_id="NEW_BUILD_ID"
   deb="/tmp/grok-bot_${version}_amd64.deb"

   curl -fL \
     "https://downloads.cursor.com/grokbot/stable/${build_id}/linux/x64/grok-bot_${version}_amd64.deb" \
     -o "$deb"
   ```

3. Compute the source hash from the downloaded bytes.

   ```bash
   nix hash file --type sha256 --sri "$deb"
   ```

4. Inspect the metadata, maintainer scripts, desktop entry, icons, executable, and native modules
   before editing the pins.

   ```bash
   archive="$(mktemp -d)"
   (
     cd "$archive"
     ar x "$deb"
     mkdir control root
     tar -xf control.tar.* -C control
     tar -xf data.tar.* -C root
   )

   sed -n '1,160p' "$archive/control/control"
   sed -n '1,240p' "$archive/control/postinst"
   sed -n '1,120p' "$archive/root/usr/share/applications/grok-bot.desktop"
   find "$archive/root/opt/Grok Bot" -type f \
     \( -name grok-bot -o -name chrome-sandbox -o -name '*.node' \) -print
   find "$archive/root/usr/share/icons/hicolor" -path '*/apps/grok-bot.png' -print
   ```

5. Replace only `version`, `buildId`, and `hash` if the layout and behavior still hold. If the
   layout, dependencies, desktop entry, or sandbox behavior changed, update the package logic
   instead. Don't add compatibility fallbacks for the old pin.

6. Build and apply.

   ```bash
   make check
   make home
   ```

7. Launch `grok-bot` and check sign-in, the computer-view pane, the desktop launcher, and
   protocol-link handling. A successful build says nothing about the proprietary application's
   runtime behavior.

To roll back, restore the previous release's three pins and rebuild.

## Failure signals

- **Source hash mismatch** - the URL did not return the reviewed bytes. Recheck the manifest,
  version, and build ID before accepting a new hash.
- **Missing `chrome-sandbox`, desktop file, icon tree, or `Exec` value** - upstream changed its
  layout. Inspect the replacement instead of relaxing the failing operation.
- **`autoPatchelfHook` reports a missing library** - the new binary or native modules gained a
  dependency. Identify the ELF consumer, then add the Nix package that owns the library.
- **Computer-view renderer crash** - check host user namespace support and the new release's
  behavior before considering `--no-sandbox`.
- **Broken `grokbot://` or `sand://` links** - check the installed desktop file, `CHROME_DESKTOP`,
  and the existing MIME owner before adding another MIME configuration path.

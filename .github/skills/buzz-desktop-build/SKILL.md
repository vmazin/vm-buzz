---
name: buzz-desktop-build
description: "Update, rebase, verify, build, package, and install the customized vm-buzz Desktop fork. Use for latest upstream desktop-v releases, Windows builds, native sidecars, MeshLLM/Vulkan, PE stack verification, and rollback-safe installation."
user-invocable: true
---

# Buzz Desktop Build

## Preconditions

- Work on `vm-buzz/windows-integration`, never upstream `main` or a detached tag.
- `upstream` must be exactly `https://github.com/block/buzz.git`.
- Do not commit or push unless explicitly requested.
- Do not run overlapping Cargo/rustc builds on Windows.

## Update upstream

1. Require a clean worktree and inspect the current branch/base.
2. Run `scripts/update-upstream.sh --check-only` to report the latest stable Desktop tag.
3. Run `scripts/update-upstream.sh [--ref desktop-vX.Y.Z]` to rebase customization commits.
4. Resolve conflicts narrowly. Preserve each invariant listed by
   `scripts/verify-vm-buzz-customizations.sh`; retire a local change only after proving upstream has
   equivalent behavior.
5. Run the verifier and focused Rust checks before building.

## Build Windows Desktop

1. Run `scripts/sync-windows-build-tree.sh [DESTINATION]` from WSL. Use the reported Windows-native
   path; do not build from `\\wsl.localhost`.
2. Run:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/build-install-windows.ps1 -SourceDir 'D:\path\reported\by\sync'
   ```

3. The helper must build all Tauri external binaries from the same revision, build the Hermes ACP
   cluster bridge, run `pnpm --dir desktop tauri build --features mesh-llm --no-bundle --ci`, apply
   `editbin /STACK:33554432`, and verify the PE header with `dumpbin`.
4. Require hashes for Desktop, all external binaries, and `hermes-acp.exe`.

### WSL sync recovery

`rsync` into `/mnt/c` can stall in `p9_client_rpc`. Treat the sync as incomplete until the
`.vm-buzz-build-tree` marker exists and the destination contains the current patched source.

1. Inspect the sync shell/rsync process group, elapsed time, process state, and `wchan`. A worker
   blocked in `p9_client_rpc` for many minutes with no marker is stalled, not merely slow.
2. Terminate only that sync process group. Never kill unrelated Cargo/rustc or Desktop processes.
3. Preserve staged and unstaged source exactly. Create one temporary tar archive from the working
   tree (not `git archive`), excluding `.git`, every `target`, `node_modules`, `dist`, and `.cache`.
4. Extract with Windows-native `tar.exe` into a fresh, explicitly named path under
   `%LOCALAPPDATA%\vm-buzz\build\`. Do not reuse or delete an unmarked destination.
5. Verify required Cargo manifests, build helper, patched source strings, and invariant verifier from
   Windows-native APIs; then create the marker and delete the temporary archive.

### Long serial builds

The build helper sets `CARGO_BUILD_JOBS=1`; first builds can take a long time, especially
`aws-lc-sys`. Lack of terminal output is not evidence of a hang. Check the one Cargo process tree:
an active `cl.exe` or `rustc.exe` compiling changing crates is progress. Do not start a second build.
Invoke the helper from a Visual Studio developer shell when `editbin.exe`/`dumpbin.exe` are not on
the default PATH.

## Install

Use `-Install` only when installation is explicitly requested, and `-Launch` only with `-Install`.
The helper stages and verifies artifacts, stops only processes executing from the target install
directory, preserves pre-patched backups, and attempts complete rollback on any replacement error.

Before installation, record the actual running executable path and the path targeted by the user's
shortcut. `%LOCALAPPDATA%` can resolve to `C:` while an existing installation lives on `D:`. In that
case, the helper's default installs a correct build that the user never launches. Pass the active
directory explicitly:

```powershell
scripts/build-install-windows.ps1 \
   -SourceDir 'C:\path\to\windows-native-source' \
   -InstallDir 'D:\Users\name\AppData\Local\Buzz' \
   -Install -Launch
```

After replacement, require all of these:

- The installed Desktop hash equals the verified build artifact hash.
- The running process path is inside the requested `InstallDir` and reports the expected version.
- Every external binary and `hermes-acp.exe` hash matches the build output.
- One-time `*.pre-vm-buzz-backup` rollback copies exist for replaced artifacts.
- Any temporary WebView debugging port used during diagnosis is closed before the normal launch.

After install, validate a normal Desktop launch, native WSS, runtime discovery, and any user-requested
provider/runtime flow. Do not claim success from compilation alone.

For Buzz repository incidents, invoke `get_project_repo_snapshot` after launch and require the
expected branch latest commit plus nonzero files. Preserve and report pre-install backups and prove
the installed executable hash equals the verified build artifact.
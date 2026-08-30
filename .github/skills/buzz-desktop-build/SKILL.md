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

## Install

Use `-Install` only when installation is explicitly requested, and `-Launch` only with `-Install`.
The helper stages and verifies artifacts, stops only processes executing from the target install
directory, preserves pre-patched backups, and attempts complete rollback on any replacement error.

After install, validate a normal Desktop launch, native WSS, runtime discovery, and any user-requested
provider/runtime flow. Do not claim success from compilation alone.
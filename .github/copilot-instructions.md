# Copilot instructions for vm-buzz

This repository is the maintained Buzz Desktop fork for the vm-clone platform. It preserves full
`block/buzz` history and carries a small Windows integration delta on top of stable `desktop-v*`
tags.

## Repository model

- `upstream` must point to `https://github.com/block/buzz.git`.
- Custom work lives on `vm-buzz/windows-integration`; never develop on `main` or a detached tag.
- Integrate upstream with `scripts/update-upstream.sh`, which rebases the customization commits onto
  the selected stable Desktop tag and runs the invariant verifier.
- Do not reintroduce a patch-application checkout workflow. The customized Rust/Tauri code is owned
  directly by this repository and should be reviewable as normal commits.
- Do not commit, push, force-push, create tags, or create GitHub releases unless explicitly requested.

## Required custom behavior

- Native WebSocket clients use Windows-native certificate roots.
- Cold runtime discovery finds packaged sidecars without requiring a warm cache.
- MeshLLM uses a 32 MiB Tokio worker stack.
- Windows MeshLLM selects the signed Vulkan runtime and adds its adjacent DLL directory to `PATH`.
- Production Desktop builds include `--features mesh-llm` and a 32 MiB PE stack reserve.
- Every Windows Tauri external binary is built from the same source revision.
- `integrations/hermes-acp-cluster-bridge` provides a local `hermes-acp.exe` that forwards ACP stdio
  to the configured Hermes deployment through WSL and kubectl. It must not copy cluster credentials.

## Build discipline

- Run `scripts/verify-vm-buzz-customizations.sh` before a build and after every upstream rebase.
- Sync the Linux source tree to a Windows-native build path with
  `scripts/sync-windows-build-tree.sh`; do not compile the Desktop from a WSL UNC path.
- Build with `scripts/build-install-windows.ps1`. Do not run overlapping Cargo/rustc builds on
  Windows; Rust metadata corruption was observed under concurrent heavy builds.
- Never install artifacts unless the user requested installation. Preserve rollback copies and
  verify hashes and the PE stack before replacement.

## External platform ownership

Buzz relay Helm/ArgoCD, Contour, PostgreSQL, Redis, MinIO, Secrets, and Hermes deployment manifests
remain owned by the sibling `vm-clone` repository. Use `VM_CLONE_REPO` when deployment diagnostics
need that checkout; do not duplicate those manifests here.
---
name: buzz-desktop-troubleshooting
description: "Diagnose Buzz Desktop connection, TLS, WSS, sidecar discovery, managed-agent, relay-mesh, MeshLLM, Vulkan, LM Studio, and ACP runtime failures. Use for UnknownIssuer, unsupported provider, missing membership snapshot, native DLL, stack overflow, or agent startup errors."
user-invocable: true
---

# Buzz Desktop Troubleshooting

## Evidence order

1. Record the installed Desktop/sidecar hashes, exact failing timestamp, relay URL, runtime ID,
   provider/model, and newest log section.
2. Ignore historical errors before the newest `=== starting ... ===` marker.
3. Separate Desktop browser HTTP, Rust native WSS, ACP harness, child agent, provider endpoint, and
   cluster relay into distinct checks.

## Known boundaries

- Native WSS `UnknownIssuer`: verify both Desktop and `buzz-acp` were built with native roots.
- `BUZZ_AGENT_PROVIDER=relay-mesh not supported`: Desktop lacks `mesh-llm` build feature or an old
  artifact remains installed.
- `relay returned no membership snapshot`: authenticated relay query lacks kind `13534`; this is a
  relay state problem, not a local native-runtime problem.
- `no live member is serving`: membership exists but no fresh trusted mesh status advertises a node.
- Windows `LoadLibraryExW` error 126 for an existing MeshLLM DLL: ensure the selected runtime's `lib`
  directory is on process `PATH`; use the signed Vulkan artifact on the target AMD host. Error 126
  names the DLL whose load failed, but can mean a transitive dependency is unresolved.
- Windows `0xc00000fd`: verify both the 32 MiB Tokio worker stack and 32 MiB PE stack reserve.
- A successful `start_managed_agent` return is only a spawn transition. Require a live PID receipt,
  current ACP/agent processes, and current log evidence.
- Lazy ACP pools may have zero child workers until work arrives; require relay connection,
  subscriptions, and online presence rather than assuming zero workers is failure.

## MeshLLM Windows DLL diagnosis

1. Record the running Desktop version/path/hash. Compare its source/build tree with the maintained
  branch before changing code; an installed older build may simply lack
  `prepare_windows_vulkan_runtime()`.
2. Inspect the selected runtime `manifest.json`, `lib` directory, file architecture, and every PE
  import using `objdump -p` or `dumpbin /dependents`.
3. For the Vulkan runtime, confirm `vulkan-1.dll` exists in Windows System32 and the GPU driver is
  healthy. Do not copy arbitrary Vulkan loaders into the bundle.
4. Reproduce `LoadLibraryExW` with the bundle `lib` directory absent/present in process `PATH` and
  with `LOAD_WITH_ALTERED_SEARCH_PATH`. On the observed `0.75.1` bundle, default loading failed with
  126 while altered-search-path loading succeeded.
5. Verify current source selects `meshllm-native-runtime-windows-x86_64-vulkan`, prepends its `lib`
  directory to process `PATH`, and pins `MESH_LLM_NATIVE_RUNTIME_BUNDLE_DIR` before host-runtime
  initialization. If the running executable predates this code, rebuild/install rather than adding
  a redundant loader patch.

## Hidden Desktop errors

When the UI collapses failures into generic copy, first prove the external service independently.
Then launch one Desktop instance with a local WebView2 debugging port and invoke the exact Tauri
command through CDP. Return only sanitized error text and non-secret state. Single-instance handoff
can make a debug launch exit immediately; stop only the existing Buzz process tree, relaunch once,
and confirm the port owner. Windows loopback is not necessarily reachable as WSL loopback.

## LM Studio

Verify `/v1/models`, the exact model ID, Chat Completions route, and configured context/output limits.
Never print API keys. Qwen reasoning models may consume small probe budgets before emitting visible
content; distinguish a valid response with reasoning from transport failure.

## External relay deployment

Use `${VM_CLONE_REPO:-../vm-clone}` for Helm, ArgoCD, Contour, PostgreSQL, Redis, MinIO, Secrets, and
NIP-43 deployment diagnostics. Keep those repairs in vm-clone.
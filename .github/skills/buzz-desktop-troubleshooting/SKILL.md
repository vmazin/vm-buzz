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
  directory is on process `PATH`; use the signed Vulkan artifact on the target AMD host.
- Windows `0xc00000fd`: verify both the 32 MiB Tokio worker stack and 32 MiB PE stack reserve.
- A successful `start_managed_agent` return is only a spawn transition. Require a live PID receipt,
  current ACP/agent processes, and current log evidence.
- Lazy ACP pools may have zero child workers until work arrives; require relay connection,
  subscriptions, and online presence rather than assuming zero workers is failure.

## LM Studio

Verify `/v1/models`, the exact model ID, Chat Completions route, and configured context/output limits.
Never print API keys. Qwen reasoning models may consume small probe budgets before emitting visible
content; distinguish a valid response with reasoning from transport failure.

## External relay deployment

Use `${VM_CLONE_REPO:-../vm-clone}` for Helm, ArgoCD, Contour, PostgreSQL, Redis, MinIO, Secrets, and
NIP-43 deployment diagnostics. Keep those repairs in vm-clone.
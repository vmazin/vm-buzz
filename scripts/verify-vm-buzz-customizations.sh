#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_text() {
  local file="$1"
  local text="$2"
  local label="$3"
  if ! grep -Fq "$text" "$ROOT_DIR/$file"; then
    echo "Invariant failed ($label): $file lacks '$text'" >&2
    exit 1
  fi
}

reject_text() {
  local file="$1"
  local text="$2"
  local label="$3"
  if grep -Fq "$text" "$ROOT_DIR/$file"; then
    echo "Invariant failed ($label): $file still contains '$text'" >&2
    exit 1
  fi
}

require_text "Cargo.toml" 'rustls-tls-native-roots' "workspace native roots"
reject_text "Cargo.toml" 'rustls-tls-webpki-roots' "workspace WebPKI roots removed"
require_text "desktop/src-tauri/Cargo.toml" 'rustls-tls-native-roots' "Desktop native roots"
reject_text "desktop/src-tauri/Cargo.toml" 'rustls-tls-webpki-roots' "Desktop WebPKI roots removed"
require_text "desktop/src-tauri/src/managed_agents/discovery.rs" \
  'resolve_workspace_command(command)' "cold bundled-sidecar discovery"
require_text "desktop/src-tauri/src/mesh_llm/mod.rs" '32 * 1024 * 1024' \
  "32 MiB MeshLLM worker stack"
require_text "desktop/src-tauri/src/mesh_llm/mod.rs" \
  'meshllm-native-runtime-windows-x86_64-vulkan' "Windows Vulkan runtime selection"
require_text "desktop/src-tauri/src/mesh_llm/mod.rs" \
  'MESH_LLM_NATIVE_RUNTIME_BUNDLE_DIR' "Vulkan bundle pinning"
require_text "desktop/src-tauri/src/mesh_llm/mod.rs" \
  'std::env::set_var("PATH", augmented_path)' "Vulkan DLL search path"
require_text "integrations/hermes-acp-cluster-bridge/src/main.rs" \
  'HERMES_ACP_SKIP_CONFIGURED_MCP=1' "Hermes cluster ACP bridge"

echo "vm-buzz customization invariants verified"
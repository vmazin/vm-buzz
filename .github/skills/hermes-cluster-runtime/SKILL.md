---
name: hermes-cluster-runtime
description: "Build, install, diagnose, and verify the vm-buzz Hermes ACP runtime bridge that connects Buzz Desktop on Windows to the Hermes agent deployed in Kubernetes through WSL kubectl exec."
user-invocable: true
---

# Hermes Cluster Runtime

`integrations/hermes-acp-cluster-bridge` builds a native Windows `hermes-acp.exe`. It forwards stdin,
stdout, and stderr to the Hermes deployment's `/opt/hermes/.venv/bin/hermes-acp` through WSL and
kubectl. It does not copy kubeconfig, Hermes configuration, or credentials to Windows.

## Defaults

- WSL distribution: `Ubuntu-24.04`
- kubectl: `/snap/bin/kubectl`
- WSL working directory: the WSL user's home
- kubeconfig: `.kube/config.k3s` relative to WSL home
- namespace/deployment/container: `hermes`
- in-container ACP: `/opt/hermes/.venv/bin/hermes-acp`

Override with `VM_BUZZ_WSL_DISTRO`, `VM_BUZZ_KUBECTL`, `VM_BUZZ_KUBECONFIG`, `VM_BUZZ_HERMES_NAMESPACE`,
`VM_BUZZ_HERMES_DEPLOYMENT`, `VM_BUZZ_HERMES_CONTAINER`, or `VM_BUZZ_HERMES_ACP_PATH`.

The bridge must not inherit cluster selection accidentally from Windows or fall back to an unrelated
`~/.kube/config`. It starts in WSL home and sets a minimal Linux `PATH` containing `/snap/bin` so
kubectl credential plugins such as `/snap/bin/aws` remain discoverable. Diagnose these failures in
order:

1. `exec: executable aws not found`: bridge WSL `PATH` omitted `/snap/bin`.
2. `namespaces "hermes" not found` while Hermes exists locally: the bridge selected a different
   kubeconfig/context, commonly EKS from `~/.kube/config` instead of local k3s.
3. Compare direct WSL and bridge-style `kubectl config current-context` plus cluster server hostname,
   without printing kubeconfig credentials.
4. Require bridge-style `kubectl -n hermes get deployment hermes -o name` to succeed before ACP.

## Verification

1. Verify Windows can run WSL kubectl with the bridge's exact working directory, `PATH`, kubeconfig,
   namespace, deployment, and container, and that the deployment is Ready.
2. Run a real ACP v2 `initialize` exchange while keeping stdin open. Require an initialize response
   identifying `hermes-agent`.
3. Install through `scripts/build-install-windows.ps1 -Install`; the bridge is placed beside
   `buzz-desktop.exe`, where forced runtime discovery finds it as `hermes-acp.exe`.
4. Force `discover_acp_providers` and require Hermes availability `available`, source `preset`, and
   auth status `not_applicable`.
5. On shutdown or failed probes, require no orphan bridge, WSL, or kubectl exec process.

## Message replies

Cluster Hermes does not receive the Buzz agent nsec and does not contain the `buzz` CLI or Buzz MCP
tools. That separation is intentional: do not copy the key into Kubernetes. The Hermes Desktop
preset sets `BUZZ_ACP_PUBLISH_OUTPUT=true`; `buzz-acp` captures ACP `agent_message_chunk` text and
publishes it through the harness's existing signed relay client after a successful turn.

Diagnose a no-reply report in this order:

1. Confirm the harness is connected to the same relay where the user sent the message. Pair-scoped
   logs use a SHA-256 suffix of the canonical relay URL; do not inspect the newest file by mtime
   alone when the same agent exists on multiple communities.
2. Require `subscribed to channel <uuid>` for the message's channel and verify the agent is an active
   member there.
3. Lazy pools have zero `hermes-acp.exe` workers until an accepted mention arrives. A controlled
   owner mention should spawn workers and reach `agent_pool_ready` before the prompt runs.
4. Require `Prompt on session`, a final `Turn ended`, and then `published ACP output reply`. A
   successful Hermes turn with no publish marker means the ACP-to-relay handoff is missing or the
   output flag was not applied.
5. Query the triggering thread and require exactly one event authored by the Hermes pubkey with the
   expected reply body. Log success alone is not sufficient.

The following observed warnings are secondary unless the requested turn needs those features:

- Obsidian MCP `401 Unauthorized` and zero connected MCP servers.
- Auxiliary title-generation timeout/fallback.
- Missing Windows-shaped `terminal.cwd` inside the Linux pod.
- One failed worker initialization when the remaining pool reaches `agent_pool_ready`.

Repeated kubectl exec WebSocket ping timeouts after the idle-pool sleep boundary are cleanup noise,
not evidence that the preceding completed reply failed.

Never print command lines that may contain Buzz auth arguments, process environments, kubeconfig, or
Hermes configuration values.
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
- namespace/deployment/container: `hermes`
- in-container ACP: `/opt/hermes/.venv/bin/hermes-acp`

Override with `VM_BUZZ_WSL_DISTRO`, `VM_BUZZ_KUBECTL`, `VM_BUZZ_HERMES_NAMESPACE`,
`VM_BUZZ_HERMES_DEPLOYMENT`, `VM_BUZZ_HERMES_CONTAINER`, or `VM_BUZZ_HERMES_ACP_PATH`.

## Verification

1. Verify Windows can run WSL kubectl and the deployment is Ready.
2. Run a real ACP v2 `initialize` exchange while keeping stdin open. Require an initialize response
   identifying `hermes-agent`.
3. Install through `scripts/build-install-windows.ps1 -Install`; the bridge is placed beside
   `buzz-desktop.exe`, where forced runtime discovery finds it as `hermes-acp.exe`.
4. Force `discover_acp_providers` and require Hermes availability `available`, source `preset`, and
   auth status `not_applicable`.
5. On shutdown or failed probes, require no orphan bridge, WSL, or kubectl exec process.

Never print command lines that may contain Buzz auth arguments, process environments, kubeconfig, or
Hermes configuration values.
# Hermes ACP cluster bridge

This small Windows executable lets Buzz Desktop use the Hermes Agent already deployed by vm-clone.
It forwards ACP stdio through `wsl.exe` to `kubectl exec -i deployment/hermes`, preserving Hermes's
cluster-side profile, tools, and credentials.

It intentionally does not proxy Hermes's OpenAI-compatible HTTP API. Buzz expects an ACP stdio
runtime for the bundled Hermes preset.

Build and install it together with Buzz Desktop through `scripts/build-install-windows.ps1`.
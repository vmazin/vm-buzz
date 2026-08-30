# vm-buzz maintenance

vm-buzz is a source-maintained fork of `block/buzz` for the vm-clone platform. The Git repository
retains upstream history and carries the Windows Desktop integrations directly in source.

## Remotes and branch

- `upstream`: `https://github.com/block/buzz.git`
- customization branch: `vm-buzz/windows-integration`
- `origin`: add the eventual GitHub fork URL before the first push

The initial base is `desktop-v0.5.20` at
`95154bee4034ca7a40b33095c2ddbde8c9aa1614`.

## Local delta

- Windows native certificate roots for Desktop and ACP sidecars.
- Cold packaged-sidecar discovery.
- 32 MiB MeshLLM worker stack and PE main-thread stack.
- Signed Vulkan native runtime selection and DLL path setup.
- Production `mesh-llm` build with all Windows external binaries from one revision.
- Source-controlled `hermes-acp.exe` bridge to the vm-clone Hermes deployment.

## Update

```bash
scripts/update-upstream.sh --check-only
scripts/update-upstream.sh
```

The update helper requires a clean customization branch and rebases its commits onto the selected
stable `desktop-v*` tag. Resolve conflicts by behavior and rerun
`scripts/verify-vm-buzz-customizations.sh`.

## Build

```bash
scripts/sync-windows-build-tree.sh
```

Use the printed Windows path:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/build-install-windows.ps1 -SourceDir 'D:\path\from\sync'
```

Add `-Install` to replace the local Buzz installation and `-Launch` to start it afterward.

## First GitHub push

After reviewing and committing the customization delta, create an empty GitHub repository and run:

```bash
git remote add origin git@github.com:<owner>/vm-buzz.git
git push -u origin vm-buzz/windows-integration
```

Do not replace `upstream` with the fork URL; both remotes are needed for future release rebases.
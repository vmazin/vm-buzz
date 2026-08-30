param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,
    [string]$InstallDir = "$env:LOCALAPPDATA\Buzz",
    [switch]$Install,
    [switch]$Launch
)

$ErrorActionPreference = "Stop"
$SourceDir = (Resolve-Path $SourceDir).Path
$TargetTriple = "x86_64-pc-windows-msvc"
$ExternalBinaries = @(
    @{ Package = "buzz-acp"; Binary = "buzz-acp" },
    @{ Package = "buzz-agent"; Binary = "buzz-agent" },
    @{ Package = "buzz-dev-mcp"; Binary = "buzz-dev-mcp" },
    @{ Package = "git-credential-nostr"; Binary = "git-credential-nostr" },
    @{ Package = "buzz-cli"; Binary = "buzz" }
)
$CargoExe = Join-Path $env:USERPROFILE ".cargo\bin\cargo.exe"
$env:RUST_MIN_STACK = "33554432"
$env:CARGO_BUILD_JOBS = "1"
$env:PATH = "$(Split-Path $CargoExe);$env:PATH"
$Corepack = Get-Command corepack -ErrorAction SilentlyContinue
$InstallStaging = $null
$PreserveInstallStaging = $false
$LocationPushed = $false

if (-not (Test-Path $CargoExe)) {
    throw "cargo.exe was not found at $CargoExe"
}
if (-not $Corepack) {
    throw "corepack is required"
}
if (-not (Get-Command editbin.exe -ErrorAction SilentlyContinue)) {
    throw "editbin.exe is required; run from a Visual Studio developer environment"
}
if (-not (Get-Command dumpbin.exe -ErrorAction SilentlyContinue)) {
    throw "dumpbin.exe is required; run from a Visual Studio developer environment"
}

$RootCargo = Join-Path $SourceDir "Cargo.toml"
$DesktopCargo = Join-Path $SourceDir "desktop\src-tauri\Cargo.toml"
$MeshSource = Join-Path $SourceDir "desktop\src-tauri\src\mesh_llm\mod.rs"
$DiscoverySource = Join-Path $SourceDir "desktop\src-tauri\src\managed_agents\discovery.rs"
$HermesBridgeManifest = Join-Path $SourceDir "integrations\hermes-acp-cluster-bridge\Cargo.toml"
$HermesBridgeExe = Join-Path $SourceDir "integrations\hermes-acp-cluster-bridge\target\release\hermes-acp.exe"

foreach ($required in @($RootCargo, $DesktopCargo, $MeshSource, $DiscoverySource, $HermesBridgeManifest)) {
    if (-not (Test-Path $required)) {
        throw "vm-buzz source is incomplete: $required is missing"
    }
}

$RootCargoText = Get-Content $RootCargo -Raw
$DesktopCargoText = Get-Content $DesktopCargo -Raw
$MeshText = Get-Content $MeshSource -Raw
$DiscoveryText = Get-Content $DiscoverySource -Raw
if ($RootCargoText -notmatch "rustls-tls-native-roots" -or $RootCargoText -match "rustls-tls-webpki-roots") {
    throw "Workspace native-roots customization is not present"
}
if ($DesktopCargoText -notmatch "rustls-tls-native-roots" -or $DesktopCargoText -match "rustls-tls-webpki-roots") {
    throw "Desktop native-roots customization is not present"
}
if ($MeshText -notmatch "meshllm-native-runtime-windows-x86_64-vulkan" -or $MeshText -notmatch "32 \* 1024 \* 1024") {
    throw "Vulkan or 32 MiB MeshLLM customization is not present"
}
if ($DiscoveryText -notmatch "resolve_workspace_command\(command\)") {
    throw "Cold bundled-sidecar discovery customization is not present"
}
$OtherRustBuilds = @(Get-Process cargo, rustc -ErrorAction SilentlyContinue)
if ($OtherRustBuilds.Count -gt 0) {
    throw "Another Cargo/rustc build is already running. Wait for it to finish before building vm-buzz."
}

$PnpmShimDir = Join-Path ([IO.Path]::GetTempPath()) "vm-buzz-build-$PID"
$PnpmShim = Join-Path $PnpmShimDir "pnpm.cmd"
try {
    New-Item -ItemType Directory -Force $PnpmShimDir | Out-Null
    Set-Content -Path $PnpmShim -Encoding Ascii -Value @"
@echo off
call "$($Corepack.Source)" pnpm %*
"@
    $env:PATH = "$PnpmShimDir;$env:PATH"

    Push-Location $SourceDir
    $LocationPushed = $true

    & $Corepack.Source pnpm install --frozen-lockfile
    if ($LASTEXITCODE -ne 0) { throw "pnpm install failed with exit code $LASTEXITCODE" }

    $CargoArgs = @("build", "--release")
    foreach ($externalBinary in $ExternalBinaries) {
        $CargoArgs += @("-p", $externalBinary.Package)
    }
    & $CargoExe @CargoArgs
    if ($LASTEXITCODE -ne 0) { throw "external binary build failed with exit code $LASTEXITCODE" }

    & $CargoExe build --release --manifest-path $HermesBridgeManifest
    if ($LASTEXITCODE -ne 0) { throw "Hermes ACP bridge build failed with exit code $LASTEXITCODE" }
    if (-not (Test-Path $HermesBridgeExe) -or (Get-Item $HermesBridgeExe).Length -eq 0) {
        throw "Hermes ACP bridge is missing or empty: $HermesBridgeExe"
    }

    $BinaryDir = Join-Path $SourceDir "desktop\src-tauri\binaries"
    New-Item -ItemType Directory -Force $BinaryDir | Out-Null
    foreach ($externalBinary in $ExternalBinaries) {
        $source = Join-Path $SourceDir "target\release\$($externalBinary.Binary).exe"
        $destination = Join-Path $BinaryDir "$($externalBinary.Binary)-$TargetTriple.exe"
        if (-not (Test-Path $source) -or (Get-Item $source).Length -eq 0) {
            throw "Built external binary is missing or empty: $source"
        }
        Copy-Item $source $destination -Force
    }

    & $Corepack.Source pnpm --dir desktop tauri build --features mesh-llm --no-bundle --ci
    if ($LASTEXITCODE -ne 0) { throw "Tauri build failed with exit code $LASTEXITCODE" }

    $DesktopExe = Join-Path $SourceDir "desktop\src-tauri\target\release\buzz-desktop.exe"
    if (-not (Test-Path $DesktopExe) -or (Get-Item $DesktopExe).Length -eq 0) {
        throw "Built Desktop executable is missing or empty: $DesktopExe"
    }
    & editbin.exe /STACK:33554432 $DesktopExe
    if ($LASTEXITCODE -ne 0) { throw "editbin failed with exit code $LASTEXITCODE" }
    $Headers = (& dumpbin.exe /headers $DesktopExe) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $Headers -notmatch "(?im)^\s*2000000\s+size of stack reserve\s*$") {
        throw "Desktop PE stack reserve is not 32 MiB after editbin"
    }

    Write-Output "desktop_path=$DesktopExe"
    Write-Output "desktop_sha256=$((Get-FileHash $DesktopExe -Algorithm SHA256).Hash)"
    foreach ($externalBinary in $ExternalBinaries) {
        $path = Join-Path $SourceDir "target\release\$($externalBinary.Binary).exe"
        Write-Output "$($externalBinary.Binary)_sha256=$((Get-FileHash $path -Algorithm SHA256).Hash)"
    }
    Write-Output "hermes-acp_sha256=$((Get-FileHash $HermesBridgeExe -Algorithm SHA256).Hash)"

    if ($Install) {
        New-Item -ItemType Directory -Force $InstallDir | Out-Null
        $InstallDir = (Resolve-Path $InstallDir).Path
        $artifacts = @{
            "buzz-desktop.exe" = $DesktopExe
            "hermes-acp.exe" = $HermesBridgeExe
        }
        foreach ($externalBinary in $ExternalBinaries) {
            $artifacts["$($externalBinary.Binary).exe"] = Join-Path $SourceDir "target\release\$($externalBinary.Binary).exe"
        }

        $InstallStaging = Join-Path $InstallDir ".vm-buzz-install-$PID"
        $StagedArtifacts = Join-Path $InstallStaging "artifacts"
        $Originals = Join-Path $InstallStaging "originals"
        New-Item -ItemType Directory -Force $StagedArtifacts, $Originals | Out-Null

        foreach ($name in $artifacts.Keys) {
            $staged = Join-Path $StagedArtifacts $name
            Copy-Item $artifacts[$name] $staged
            if ((Get-FileHash $staged -Algorithm SHA256).Hash -ne
                (Get-FileHash $artifacts[$name] -Algorithm SHA256).Hash) {
                throw "Staged artifact verification failed: $name"
            }

            $target = Join-Path $InstallDir $name
            if (Test-Path $target) {
                Copy-Item $target (Join-Path $Originals $name)
                $backup = "$target.pre-vm-buzz-backup"
                if (-not (Test-Path $backup)) {
                    Copy-Item $target $backup
                }
            }
        }

        $OwnedNames = @($artifacts.Keys)
        Get-CimInstance Win32_Process |
            Where-Object {
                $_.ExecutablePath -and
                $_.Name -in $OwnedNames -and
                ([IO.Path]::GetDirectoryName($_.ExecutablePath).TrimEnd("\") -ieq $InstallDir.TrimEnd("\"))
            } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

        try {
            foreach ($name in $artifacts.Keys) {
                Copy-Item (Join-Path $StagedArtifacts $name) (Join-Path $InstallDir $name) -Force
            }
        } catch {
            $InstallError = $_
            $RollbackErrors = @()
            foreach ($name in $artifacts.Keys) {
                $target = Join-Path $InstallDir $name
                $original = Join-Path $Originals $name
                try {
                    if (Test-Path $original) {
                        Copy-Item $original $target -Force
                    } elseif (Test-Path $target) {
                        Remove-Item $target -Force -ErrorAction Stop
                    }
                } catch {
                    $RollbackErrors += "$name`: $($_.Exception.Message)"
                }
            }
            if ($RollbackErrors.Count -gt 0) {
                $PreserveInstallStaging = $true
                throw "Installation failed and rollback was incomplete. Recovery copies remain at $InstallStaging. Rollback errors: $($RollbackErrors -join '; ')"
            }
            throw $InstallError
        }

        Write-Output "installed_dir=$InstallDir"
        if ($Launch) {
            Start-Process (Join-Path $InstallDir "buzz-desktop.exe")
            Write-Output "launched=true"
        }
    } elseif ($Launch) {
        throw "-Launch requires -Install"
    }
} finally {
    if ($LocationPushed) {
        Pop-Location
    }
    Remove-Item $PnpmShimDir -Recurse -Force -ErrorAction SilentlyContinue
    if ($InstallStaging -and -not $PreserveInstallStaging) {
        Remove-Item $InstallStaging -Recurse -Force -ErrorAction SilentlyContinue
    }
}

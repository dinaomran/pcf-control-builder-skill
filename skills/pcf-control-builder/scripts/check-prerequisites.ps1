<#
.SYNOPSIS
    Read-only prerequisite report for PCF control development.

.DESCRIPTION
    Inspects (never installs, never authenticates, never writes to an
    environment): Node.js, npm, PAC CLI, .NET SDK, MSBuild, Visual Studio,
    VS Code, the Power Platform Tools VS Code extension, git, and the
    presence of PCF/solution project files. Cross-checks compatibility
    against package.json "engines" and the generated project when present.

    This script performs no installation, no authentication, no PATH
    changes, and no Dataverse environment access of any kind.

.PARAMETER ProjectPath
    Path to inspect. Defaults to the current directory. Must exist.

.PARAMETER Json
    Emit a machine-readable JSON report instead of a formatted table.

.PARAMETER SkipVsCodeExtensions
    Skip scanning ~/.vscode/extensions for Power Platform tooling. Scanned
    by default.

.PARAMETER FailOnWarn
    Exit non-zero when only WARN-level findings are present (no BLOCK).
    Off by default: a clean-but-imperfect result (e.g. uncommitted git
    changes, a dual PAC CLI install) is not a script failure on its own,
    and treating it as one makes this script look broken on nearly every
    real project. Blocking findings always exit non-zero regardless of
    this switch.

.OUTPUTS
    Exit code 0 = all checks OK, informational only, or warnings present
                  without -FailOnWarn.
    Exit code 1 = warnings present and -FailOnWarn was specified.
    Exit code 2 = at least one blocking prerequisite is missing.
    Exit code 3 = script usage error (bad -ProjectPath).

.EXAMPLE
    .\check-prerequisites.ps1 -ProjectPath "C:\repos\My Control"

.EXAMPLE
    .\check-prerequisites.ps1 -Json | ConvertFrom-Json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectPath = ".",

    [Parameter(Mandatory = $false)]
    [switch]$Json,

    [Parameter(Mandatory = $false)]
    [switch]$SkipVsCodeExtensions,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnWarn
)

$IncludeVsCodeExtensions = -not $SkipVsCodeExtensions

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ProjectPath)) {
    [Console]::Error.WriteLine("ProjectPath does not exist: $ProjectPath")
    exit 3
}
$resolvedProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path

$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [string]$Tool,
        [string]$Status,      # OK | WARN | BLOCK | INFO
        [string]$Version = "",
        [string]$Path = "",
        [string]$Note = ""
    )
    $results.Add([PSCustomObject]@{
        Tool    = $Tool
        Status  = $Status
        Version = $Version
        Path    = $Path
        Note    = $Note
    }) | Out-Null
}

function Invoke-Safe {
    param([scriptblock]$Script)
    try {
        & $Script 2>$null
    } catch {
        $null
    }
}

# --- Node.js -----------------------------------------------------------
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    $nodeVersion = (Invoke-Safe { node --version }) -join ""
    Add-Result -Tool "Node.js" -Status "OK" -Version $nodeVersion -Path $nodeCmd.Source
} else {
    $candidates = @(
        (Join-Path $env:ProgramFiles "nodejs\node.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "nodejs\node.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\nodejs\node.exe"),
        (Join-Path $env:APPDATA "nvm")
    )
    $found = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    if ($found) {
        Add-Result -Tool "Node.js" -Status "WARN" -Note "Not on PATH, but found at: $($found -join '; '). Open a new shell or check your version manager."
    } else {
        Add-Result -Tool "Node.js" -Status "BLOCK" -Note "Not found. Required for PAC pcf init, npm scripts, and the React preview. Do not auto-install - report to the user."
    }
}

# --- npm -----------------------------------------------------------
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
if ($npmCmd) {
    $npmVersion = (Invoke-Safe { npm --version }) -join ""
    Add-Result -Tool "npm" -Status "OK" -Version $npmVersion -Path $npmCmd.Source
} else {
    Add-Result -Tool "npm" -Status "BLOCK" -Note "Not found. Ships with Node.js - resolve Node.js first."
}

# --- package.json engines compatibility --------------------------------
$packageJsonPath = Join-Path $resolvedProjectPath "package.json"
if (Test-Path -LiteralPath $packageJsonPath) {
    try {
        $pkg = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
        if ($pkg.engines -and $pkg.engines.node) {
            Add-Result -Tool "package.json engines.node" -Status "INFO" -Version $pkg.engines.node -Note "Compare against the installed Node.js version above; this script does not evaluate semver ranges."
        }
    } catch {
        Add-Result -Tool "package.json" -Status "WARN" -Note "Found but could not be parsed as JSON: $($_.Exception.Message)"
    }
}

# --- PAC CLI -----------------------------------------------------------
$pacCmd = Get-Command pac -ErrorAction SilentlyContinue
if ($pacCmd) {
    $pacVersionRaw = (Invoke-Safe { pac --version }) -join "`n"
    $pacVersion = ($pacVersionRaw -split "`n" | Where-Object { $_ -match "Version:" }) -replace "Version:\s*", ""
    Add-Result -Tool "PAC CLI" -Status "OK" -Version ($pacVersion -join "").Trim() -Path $pacCmd.Source -Note "Query syntax is 'pac <group> <verb> help', not --help."
} else {
    Add-Result -Tool "PAC CLI" -Status "BLOCK" -Note "Not found. Required for scaffolding, packaging, and deployment. Recommend Power Platform Tools for VS Code, or the Windows MSI as a fallback. Do not auto-install."
}

# --- VS Code Power Platform Tools extension -----------------------------
if ($IncludeVsCodeExtensions) {
    $extRoot = Join-Path $env:USERPROFILE ".vscode\extensions"
    if (Test-Path -LiteralPath $extRoot) {
        $ppExtensions = Get-ChildItem -LiteralPath $extRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*powerplatform*" -or $_.Name -like "*isvexptools*" }
        if ($ppExtensions) {
            $names = ($ppExtensions | Select-Object -ExpandProperty Name) -join "; "
            if ($pacCmd) {
                Add-Result -Tool "VS Code Power Platform Tools" -Status "WARN" -Note "Extension present ($names) AND a separate PAC CLI is on PATH ($($pacCmd.Source)). These can drift in version. Report both to the user; do not reconcile automatically."
            } else {
                Add-Result -Tool "VS Code Power Platform Tools" -Status "INFO" -Note "Extension present ($names). It ships its own bundled PAC CLI, usable from VS Code even though none is on PATH."
            }
        } else {
            Add-Result -Tool "VS Code Power Platform Tools" -Status "INFO" -Note "Not installed. Preferred channel for PAC CLI when no PATH install exists."
        }
    } else {
        Add-Result -Tool "VS Code Power Platform Tools" -Status "INFO" -Note "No ~/.vscode/extensions directory found."
    }
}

# --- .NET SDK -----------------------------------------------------------
$dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
if ($dotnetCmd) {
    $dotnetVersion = (Invoke-Safe { dotnet --version }) -join ""
    $sdks = (Invoke-Safe { dotnet --list-sdks }) -join "; "
    Add-Result -Tool ".NET SDK" -Status "OK" -Version $dotnetVersion -Path $dotnetCmd.Source -Note "Installed SDKs: $sdks"
} else {
    Add-Result -Tool ".NET SDK" -Status "WARN" -Note "Not found. Needed to build a solution project or run 'pac pcf push' (which builds a temporary solution wrapper). MSBuild is an alternative - see below."
}

# --- MSBuild (via PATH, then vswhere - never a hard-coded VS path) -----
$msbuildCmd = Get-Command msbuild -ErrorAction SilentlyContinue
if ($msbuildCmd) {
    Add-Result -Tool "MSBuild" -Status "OK" -Path $msbuildCmd.Source
} else {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path -LiteralPath $vswhere) {
        $msbuildPath = Invoke-Safe {
            & $vswhere -products * -requires Microsoft.Component.MSBuild -latest -find "MSBuild\**\Bin\MSBuild.exe"
        }
        $msbuildPath = ($msbuildPath | Select-Object -First 1)
        if ($msbuildPath -and (Test-Path -LiteralPath $msbuildPath)) {
            Add-Result -Tool "MSBuild" -Status "INFO" -Path $msbuildPath -Note "Not on PATH. Use a Developer PowerShell for VS, or invoke this full path directly. Do not edit the machine-wide PATH."
        } else {
            if ($dotnetCmd) {
                Add-Result -Tool "MSBuild" -Status "INFO" -Note "Not found via vswhere. .NET SDK is present - prefer 'dotnet build'."
            } else {
                Add-Result -Tool "MSBuild" -Status "BLOCK" -Note "Not found via PATH or vswhere, and .NET SDK is also missing. Solution packaging cannot build."
            }
        }
    } else {
        Add-Result -Tool "MSBuild" -Status "INFO" -Note "vswhere.exe not found; cannot discover MSBuild via Visual Studio. Rely on 'dotnet build' if the .NET SDK is present."
    }
}

# --- VS Code -----------------------------------------------------------
$codeCmd = Get-Command code -ErrorAction SilentlyContinue
if ($codeCmd) {
    Add-Result -Tool "VS Code" -Status "INFO" -Path $codeCmd.Source
} else {
    Add-Result -Tool "VS Code" -Status "INFO" -Note "Not found on PATH."
}

# --- git -----------------------------------------------------------
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    $gitVersion = (Invoke-Safe { git --version }) -join ""
    Add-Result -Tool "git" -Status "OK" -Version $gitVersion -Path $gitCmd.Source

    Push-Location -LiteralPath $resolvedProjectPath
    try {
        $isRepo = Invoke-Safe { git rev-parse --is-inside-work-tree }
        if ($isRepo -eq "true") {
            $dirty = Invoke-Safe { git status --short }
            if ($dirty) {
                Add-Result -Tool "git working tree" -Status "WARN" -Note "Uncommitted changes present. Preserve them; do not commit, stash, reset, or clean without an explicit request."
            } else {
                Add-Result -Tool "git working tree" -Status "OK" -Note "Clean."
            }
        } else {
            Add-Result -Tool "git repository" -Status "INFO" -Note "ProjectPath is not inside a git repository. No undo safety net for edits made here."
        }
    } finally {
        Pop-Location
    }
} else {
    Add-Result -Tool "git" -Status "WARN" -Note "Not found. Cannot check working-tree state before edits."
}

# --- Existing PCF / solution project files -----------------------------
# Excluded from the recursive scan: these directories can hold thousands of
# copied/generated files (dependencies, build output) that are never the
# real project source, and walking into them is slow and can surface a
# stale copy of a manifest instead of the real one.
$excludedDirPattern = '\\(node_modules|bin|obj|out|dist|\.git)(\\|$)'
$pcfProj = Get-ChildItem -LiteralPath $resolvedProjectPath -Recurse -Filter "*.pcfproj" -ErrorAction SilentlyContinue -File |
    Where-Object { $_.FullName -notmatch $excludedDirPattern }
$manifest = Get-ChildItem -LiteralPath $resolvedProjectPath -Recurse -Filter "ControlManifest.Input.xml" -ErrorAction SilentlyContinue -File |
    Where-Object { $_.FullName -notmatch $excludedDirPattern }
$cdsproj = Get-ChildItem -LiteralPath $resolvedProjectPath -Recurse -Filter "*.cdsproj" -ErrorAction SilentlyContinue -File |
    Where-Object { $_.FullName -notmatch $excludedDirPattern }
$specFiles = Get-ChildItem -LiteralPath (Join-Path $resolvedProjectPath "docs\pcf") -Filter "*-spec.md" -ErrorAction SilentlyContinue -File

if ($pcfProj -or $manifest) {
    Add-Result -Tool "Existing PCF project" -Status "INFO" -Note "Found $($pcfProj.Count) *.pcfproj and $($manifest.Count) ControlManifest.Input.xml under $resolvedProjectPath. This is likely an existing-project update, not a new scaffold."
} else {
    Add-Result -Tool "Existing PCF project" -Status "INFO" -Note "None found under $resolvedProjectPath. New-project workflow applies."
}
if ($cdsproj) {
    Add-Result -Tool "Existing solution project" -Status "INFO" -Note "Found $($cdsproj.Count) *.cdsproj under $resolvedProjectPath."
}
if ($specFiles) {
    Add-Result -Tool "Existing control spec" -Status "INFO" -Note "Found: $(($specFiles | Select-Object -ExpandProperty Name) -join '; '). Read before asking anything (resume protocol)."
}

# --- Report --------------------------------------------------------
if ($Json) {
    $results | ConvertTo-Json -Depth 5
} else {
    # Note is deliberately excluded from the table: Format-Table -AutoSize
    # truncates/drops whichever column doesn't fit the console width, and
    # Note is the field carrying the actual remediation text. Every Note is
    # printed in full below instead, grouped by status.
    $results | Format-Table -Property Tool, Status, Version, Path -AutoSize -Wrap

    $blocks = $results | Where-Object { $_.Status -eq "BLOCK" }
    $warnings = $results | Where-Object { $_.Status -eq "WARN" }
    $notes = $results | Where-Object { $_.Status -in @("INFO", "OK") -and $_.Note }

    if ($blocks) {
        Write-Output ""
        Write-Output "BLOCKS (must be resolved by the user before scaffolding/building/deploying):"
        foreach ($b in $blocks) { Write-Output "  - $($b.Tool): $($b.Note)" }
    }
    if ($warnings) {
        Write-Output ""
        Write-Output "WARNINGS:"
        foreach ($w in $warnings) { Write-Output "  - $($w.Tool): $($w.Note)" }
    }
    if ($notes) {
        Write-Output ""
        Write-Output "NOTES:"
        foreach ($n in $notes) { Write-Output "  - $($n.Tool): $($n.Note)" }
    }
    if (-not $blocks -and -not $warnings -and -not $notes) {
        Write-Output ""
        Write-Output "No blocks, warnings, or notes."
    }
}

if ($results | Where-Object { $_.Status -eq "BLOCK" }) {
    exit 2
} elseif ($FailOnWarn -and ($results | Where-Object { $_.Status -eq "WARN" })) {
    exit 1
} else {
    exit 0
}

<#
.SYNOPSIS
    Read-only assessment of an existing (or absent) PCF project.

.DESCRIPTION
    Reports facts about a PCF project and any associated solution project:
    manifest metadata, control-type as literally written, properties,
    datasets/feature-usage/resources, package.json scripts and dependency
    versions, lint/tsconfig configuration style, and solution identity.

    This script reports facts. It does not recommend upgrades, does not
    flag dependency versions as "old", and does not judge tooling choices
    -- that judgment belongs to the agent and the user, together, not to
    this script. It never modifies anything.

.PARAMETER ProjectPath
    Path to inspect. Defaults to the current directory.

.PARAMETER Json
    Emit a machine-readable JSON report instead of a formatted summary.

.PARAMETER FailOnWarn
    Exit non-zero when a naming-collision warning is present. Off by
    default -- an inspection is informational, not a pass/fail check, so a
    warning alone should not read as this script having failed.

.OUTPUTS
    Exit code 0 = inspection completed (no project found at all is not a
                  failure), or a naming-collision warning exists without
                  -FailOnWarn.
    Exit code 1 = inspection completed, a naming-collision warning exists,
                  and -FailOnWarn was specified.
    Exit code 3 = script usage error (bad -ProjectPath).

.EXAMPLE
    .\inspect-pcf-project.ps1 -ProjectPath "C:\repos\My Control"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectPath = ".",

    [Parameter(Mandatory = $false)]
    [switch]$Json,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnWarn
)

# Directories that can hold thousands of copied/generated files that are
# never the real project source -- excluded from every recursive scan
# below so inspection stays fast and doesn't pick up a stale copy.
$excludedDirPattern = '\\(node_modules|bin|obj|out|dist|\.git)(\\|$)'

if (-not (Test-Path -LiteralPath $ProjectPath)) {
    [Console]::Error.WriteLine("ProjectPath does not exist: $ProjectPath")
    exit 3
}
$root = (Resolve-Path -LiteralPath $ProjectPath).Path

$report = [ordered]@{
    ProjectPath      = $root
    PcfProjects      = @()
    Manifests        = @()
    SolutionProjects = @()
    Warnings         = @()
}

function Read-TextSafe {
    param([string]$Path)
    try { Get-Content -LiteralPath $Path -Raw -ErrorAction Stop } catch { $null }
}

# --- Locate project files ------------------------------------------------
$pcfProjFiles  = Get-ChildItem -LiteralPath $root -Recurse -Filter "*.pcfproj" -ErrorAction SilentlyContinue -File |
    Where-Object { $_.FullName -notmatch $excludedDirPattern }
$manifestFiles = Get-ChildItem -LiteralPath $root -Recurse -Filter "ControlManifest.Input.xml" -ErrorAction SilentlyContinue -File |
    Where-Object { $_.FullName -notmatch $excludedDirPattern }
$cdsprojFiles  = Get-ChildItem -LiteralPath $root -Recurse -Filter "*.cdsproj" -ErrorAction SilentlyContinue -File |
    Where-Object { $_.FullName -notmatch $excludedDirPattern }
$packageJsons  = Get-ChildItem -LiteralPath $root -Recurse -Filter "package.json" -ErrorAction SilentlyContinue -File |
    Where-Object { $_.FullName -notmatch $excludedDirPattern }

$report.PcfProjects = $pcfProjFiles | ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\') }

if (-not $manifestFiles) {
    $report.Note = "No ControlManifest.Input.xml found under $root. Treat as a new-project workflow (S3 Branch A)."
    if ($Json) { $report | ConvertTo-Json -Depth 8 } else {
        Write-Output $report.Note
    }
    exit 0
}

# --- Per-manifest inspection ----------------------------------------------
foreach ($manifestFile in $manifestFiles) {
    $manifestDir = Split-Path -Path $manifestFile.FullName -Parent
    $relManifest = $manifestFile.FullName.Substring($root.Length).TrimStart('\')

    $entry = [ordered]@{
        Path              = $relManifest
        WellFormed        = $true
        Namespace         = $null
        Constructor       = $null
        Version           = $null
        ControlType       = $null
        Properties        = @()
        HasDataSet        = $false
        PropertySets      = @()
        FeatureUsage      = @()
        HasExternalService = $false
        Resources         = @()
        PlatformLibraries = @()
    }

    try {
        [xml]$xml = Read-TextSafe -Path $manifestFile.FullName
        $controlNode = $xml.manifest.control
        if (-not $controlNode) { $controlNode = $xml.SelectSingleNode("//control") }

        if ($controlNode) {
            $entry.Namespace   = $controlNode.namespace
            $entry.Constructor = $controlNode.constructor
            $entry.Version     = $controlNode.version
            $entry.ControlType = $controlNode.'control-type'   # literal value; do not assume

            foreach ($p in $controlNode.property) {
                $entry.Properties += [ordered]@{
                    name       = $p.name
                    ofType     = $p.'of-type'
                    ofTypeGroup = $p.'of-type-group'
                    usage      = $p.usage
                    required   = $p.required
                }
            }

            $dataSetNodes = $controlNode.'data-set'
            if ($dataSetNodes) {
                $entry.HasDataSet = $true
                foreach ($ds in $dataSetNodes) {
                    if ($ds.'property-set') {
                        foreach ($ps in $ds.'property-set') {
                            $entry.PropertySets += [ordered]@{ dataSet = $ds.name; name = $ps.name; ofType = $ps.'of-type' }
                        }
                    }
                }
            }

            if ($controlNode.'feature-usage' -and $controlNode.'feature-usage'.'uses-feature') {
                foreach ($f in $controlNode.'feature-usage'.'uses-feature') {
                    $entry.FeatureUsage += [ordered]@{ name = $f.name; required = $f.required }
                }
            }

            if ($controlNode.'external-service-usage') {
                $entry.HasExternalService = $true
            }

            if ($controlNode.resources) {
                foreach ($childName in @("code", "css", "resx", "img")) {
                    foreach ($r in $controlNode.resources.$childName) {
                        if ($r) {
                            $resPath = $r.path
                            $exists = $false
                            if ($resPath) {
                                $exists = Test-Path -LiteralPath (Join-Path $manifestDir $resPath)
                            }
                            $entry.Resources += [ordered]@{
                                type   = $childName
                                path   = $resPath
                                order  = $r.order
                                version = $r.version
                                exists = $exists
                            }
                        }
                    }
                }
                foreach ($pl in $controlNode.resources.'platform-library') {
                    if ($pl) {
                        $entry.PlatformLibraries += [ordered]@{ name = $pl.name; version = $pl.version }
                    }
                }
            }
        }
    } catch {
        $entry.WellFormed = $false
        $entry.ParseError = $_.Exception.Message
    }

    $report.Manifests += $entry
}

# --- package.json inspection ----------------------------------------------
$report.PackageJsons = @()
foreach ($pkgFile in $packageJsons) {
    $relPkg = $pkgFile.FullName.Substring($root.Length).TrimStart('\')
    $pkgEntry = [ordered]@{
        Path         = $relPkg
        Scripts      = @()
        Dependencies = @()
        DevDependencies = @()
        Engines      = $null
        LockFile     = $null
        LintConfig   = "none detected"
        TsconfigExtends = $null
    }
    try {
        $pkg = Get-Content -LiteralPath $pkgFile.FullName -Raw | ConvertFrom-Json
        if ($pkg.scripts) {
            $pkgEntry.Scripts = $pkg.scripts.PSObject.Properties | ForEach-Object { $_.Name }
        }
        if ($pkg.dependencies) {
            $pkgEntry.Dependencies = $pkg.dependencies.PSObject.Properties | ForEach-Object { "$($_.Name)@$($_.Value)" }
        }
        if ($pkg.devDependencies) {
            $pkgEntry.DevDependencies = $pkg.devDependencies.PSObject.Properties | ForEach-Object { "$($_.Name)@$($_.Value)" }
        }
        if ($pkg.engines) {
            $pkgEntry.Engines = ($pkg.engines.PSObject.Properties | ForEach-Object { "$($_.Name): $($_.Value)" }) -join "; "
        }
    } catch {
        $pkgEntry.ParseError = $_.Exception.Message
    }

    $pkgDir = Split-Path -Path $pkgFile.FullName -Parent
    if (Test-Path -LiteralPath (Join-Path $pkgDir "package-lock.json")) { $pkgEntry.LockFile = "package-lock.json" }
    elseif (Test-Path -LiteralPath (Join-Path $pkgDir "npm-shrinkwrap.json")) { $pkgEntry.LockFile = "npm-shrinkwrap.json" }

    $hasLegacyEslint = @(".eslintrc", ".eslintrc.json", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.yml") |
        Where-Object { Test-Path -LiteralPath (Join-Path $pkgDir $_) }
    $hasFlatEslint = @("eslint.config.js", "eslint.config.mjs", "eslint.config.cjs") |
        Where-Object { Test-Path -LiteralPath (Join-Path $pkgDir $_) }
    if ($hasFlatEslint) { $pkgEntry.LintConfig = "flat config: $($hasFlatEslint -join ', ')" }
    elseif ($hasLegacyEslint) { $pkgEntry.LintConfig = "legacy config: $($hasLegacyEslint -join ', ')" }
    elseif ($pkgEntry.Scripts -contains "lint") { $pkgEntry.LintConfig = "lint script present, no local config file found (may rely on pcf-scripts defaults)" }

    $tsconfigPath = Join-Path $pkgDir "tsconfig.json"
    if (Test-Path -LiteralPath $tsconfigPath) {
        try {
            $ts = Get-Content -LiteralPath $tsconfigPath -Raw | ConvertFrom-Json
            $pkgEntry.TsconfigExtends = $ts.extends
        } catch {
            $pkgEntry.TsconfigExtends = "(could not parse tsconfig.json)"
        }
    }

    $report.PackageJsons += $pkgEntry
}

# --- Solution project inspection ------------------------------------------
foreach ($cdsproj in $cdsprojFiles) {
    $solDir = Split-Path -Path $cdsproj.FullName -Parent
    $relCdsproj = $cdsproj.FullName.Substring($root.Length).TrimStart('\')
    $solEntry = [ordered]@{
        Path               = $relCdsproj
        SolutionPackageType = $null
        ProjectReferences  = @()
        UniqueName         = $null
        DisplayName        = $null
        Version            = $null
        PublisherPrefix    = $null
    }
    try {
        [xml]$cds = Read-TextSafe -Path $cdsproj.FullName
        $pkgTypeNode = $cds.SelectSingleNode("//SolutionPackageType")
        if ($pkgTypeNode) { $solEntry.SolutionPackageType = $pkgTypeNode.InnerText }
        $refs = $cds.SelectNodes("//ProjectReference")
        if ($refs) {
            foreach ($r in $refs) { $solEntry.ProjectReferences += $r.Include }
        }
    } catch {
        $solEntry.ParseError = $_.Exception.Message
    }

    $solutionXmlPath = Join-Path $solDir "src\Other\Solution.xml"
    if (Test-Path -LiteralPath $solutionXmlPath) {
        try {
            [xml]$solXml = Read-TextSafe -Path $solutionXmlPath
            $solEntry.UniqueName  = $solXml.ImportExportXml.SolutionManifest.UniqueName
            $solEntry.Version     = $solXml.ImportExportXml.SolutionManifest.Version
            $localizedNames = $solXml.ImportExportXml.SolutionManifest.LocalizedNames
            if ($localizedNames -and $localizedNames.LocalizedName) {
                $ln = $localizedNames.LocalizedName
                if ($ln -is [array]) { $solEntry.DisplayName = $ln[0].description } else { $solEntry.DisplayName = $ln.description }
            }
            $solEntry.PublisherPrefix = $solXml.ImportExportXml.SolutionManifest.Publisher.CustomizationPrefix
        } catch {
            $solEntry.SolutionXmlParseError = $_.Exception.Message
        }
    }

    $report.SolutionProjects += $solEntry
}

# --- Name-collision check --------------------------------------------------
$pcfNames = $pcfProjFiles | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
$cdsNames = $cdsprojFiles | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
$solutionUniqueNames = $report.SolutionProjects | ForEach-Object { $_.UniqueName } | Where-Object { $_ }

foreach ($pn in $pcfNames) {
    foreach ($cn in $cdsNames) {
        if ($pn -and $cn -and ($pn -eq $cn)) {
            $report.Warnings += "PCF project name '$pn' is identical to a solution project name. Give them distinct names (see the naming-collision rule in manifest-design.md / deployment-and-alm.md)."
        }
    }
    foreach ($sn in $solutionUniqueNames) {
        if ($pn -and $sn -and ($pn -eq $sn)) {
            $report.Warnings += "PCF project name '$pn' is identical to a solution unique name '$sn'. Rename one of them before packaging."
        }
    }
}

# --- Output ------------------------------------------------------------
if ($Json) {
    $report | ConvertTo-Json -Depth 8
} else {
    Write-Output "Project path: $($report.ProjectPath)"
    Write-Output ""
    Write-Output "PCF projects found: $($report.PcfProjects -join ', ')"
    foreach ($m in $report.Manifests) {
        Write-Output ""
        Write-Output "Manifest: $($m.Path)"
        Write-Output "  Well-formed: $($m.WellFormed)"
        Write-Output "  namespace=$($m.Namespace) constructor=$($m.Constructor) version=$($m.Version)"
        Write-Output "  control-type (as written): $($m.ControlType)"
        Write-Output "  Properties: $($m.Properties.Count)"
        Write-Output "  Has data-set: $($m.HasDataSet)  Property-sets: $($m.PropertySets.Count)"
        Write-Output "  Feature usage: $(($m.FeatureUsage | ForEach-Object { "$($_.name)(required=$($_.required))" }) -join ', ')"
        Write-Output "  External-service-usage present: $($m.HasExternalService)"
        Write-Output "  Resources: $($m.Resources.Count)  Platform libraries: $(($m.PlatformLibraries | ForEach-Object { "$($_.name)@$($_.version)" }) -join ', ')"
    }
    foreach ($p in $report.PackageJsons) {
        Write-Output ""
        Write-Output "package.json: $($p.Path)"
        Write-Output "  Scripts: $($p.Scripts -join ', ')"
        Write-Output "  Lock file: $($p.LockFile)"
        Write-Output "  Lint config: $($p.LintConfig)"
        Write-Output "  tsconfig extends: $($p.TsconfigExtends)"
    }
    foreach ($s in $report.SolutionProjects) {
        Write-Output ""
        Write-Output "Solution project: $($s.Path)"
        Write-Output "  SolutionPackageType: $($s.SolutionPackageType)"
        Write-Output "  Unique name: $($s.UniqueName)  Display name: $($s.DisplayName)  Version: $($s.Version)"
        Write-Output "  Publisher prefix: $($s.PublisherPrefix)"
    }
    if ($report.Warnings.Count -gt 0) {
        Write-Output ""
        Write-Output "WARNINGS:"
        foreach ($w in $report.Warnings) { Write-Output "  - $w" }
    }
}

if ($FailOnWarn -and $report.Warnings.Count -gt 0) { exit 1 } else { exit 0 }

<#
.SYNOPSIS
    Read-only manifest/resource/RESX consistency validation for a PCF control.

.DESCRIPTION
    Catches at design time the defects that otherwise surface as build
    failures or a blank control at runtime:
      1. ControlManifest.Input.xml is well-formed XML.
      2. Every <resources> child path resolves to an existing file.
      3. Every manifest localization key exists in at least one declared
         RESX file (BLOCK if missing from all of them; WARN if present in
         some but not others -- an in-progress translation, not a defect).
      4. RESX keys not referenced by the manifest are reported (dead strings).
      5. Property names are unique; scaffold placeholder names are flagged.
      6. control-type / platform-library presence consistency.
      7. If ManifestTypes.d.ts exists, cross-check IInputs/IOutputs coverage.
      8. Optional feature-usage entries get a fallback-check reminder.
      9. React/Fluent duplicate-bundling heuristic (package.json deps vs
         platform-library entries).

    This script never modifies the manifest, RESX files, or runs a build.
    It reports; the agent and user decide what to do with the findings.

.PARAMETER ProjectPath
    Path to inspect. Defaults to the current directory.

.PARAMETER ManifestPath
    Optional explicit path to a ControlManifest.Input.xml. When omitted,
    every ControlManifest.Input.xml found under ProjectPath is validated.

.PARAMETER Json
    Emit a machine-readable JSON report instead of a formatted summary.

.PARAMETER FailOnWarn
    Exit non-zero when only WARN-level findings are present (no BLOCK).
    Off by default -- a WARN (e.g. an unused RESX string) is a heads-up,
    not a validation failure, and treating it as one makes this script
    look broken on nearly every real project. BLOCK findings always exit
    non-zero regardless of this switch.

.OUTPUTS
    Exit code 0 = no BLOCK findings (WARN/INFO findings may still be
                  present unless -FailOnWarn was specified).
    Exit code 1 = WARN findings only, and -FailOnWarn was specified.
    Exit code 2 = at least one BLOCK finding.
    Exit code 3 = script usage error.

.EXAMPLE
    .\validate-pcf-project.ps1 -ProjectPath "C:\repos\My Control"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectPath = ".",

    [Parameter(Mandatory = $false)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [switch]$Json,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnWarn
)

# Directories that can hold thousands of copied/generated files that are
# never the real project source -- excluded from every recursive scan
# below so validation stays fast and doesn't pick up a stale copy.
$excludedDirPattern = '\\(node_modules|bin|obj|out|dist|\.git)(\\|$)'

if (-not (Test-Path -LiteralPath $ProjectPath)) {
    [Console]::Error.WriteLine("ProjectPath does not exist: $ProjectPath")
    exit 3
}
$root = (Resolve-Path -LiteralPath $ProjectPath).Path

if ($ManifestPath) {
    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        [Console]::Error.WriteLine("ManifestPath does not exist: $ManifestPath")
        exit 3
    }
    $manifestFiles = @(Get-Item -LiteralPath $ManifestPath)
} else {
    $manifestFiles = @(Get-ChildItem -LiteralPath $root -Recurse -Filter "ControlManifest.Input.xml" -ErrorAction SilentlyContinue -File |
        Where-Object { $_.FullName -notmatch $excludedDirPattern })
}

$findings = New-Object System.Collections.Generic.List[object]

function Add-Finding {
    param([string]$Severity, [string]$Rule, [string]$File, [string]$Detail)
    $findings.Add([PSCustomObject]@{
        Severity = $Severity   # BLOCK | WARN | INFO
        Rule     = $Rule
        File     = $File
        Detail   = $Detail
    }) | Out-Null
}

$placeholderNames = @("myFirstProperty", "sampleProperty", "property1", "sampleDataSet")

if ($manifestFiles.Count -eq 0) {
    if ($Json) {
        @{ Findings = @(); Note = "No ControlManifest.Input.xml found under $root." } | ConvertTo-Json -Depth 5
    } else {
        Write-Output "No ControlManifest.Input.xml found under $root. Nothing to validate."
    }
    exit 0
}

foreach ($manifestFile in $manifestFiles) {
    $manifestDir = Split-Path -Path $manifestFile.FullName -Parent
    $relManifest = $manifestFile.FullName.Substring($root.Length).TrimStart('\')
    $rawXml = Get-Content -LiteralPath $manifestFile.FullName -Raw

    # 1. Well-formed XML -----------------------------------------------
    $xml = $null
    try {
        $xml = New-Object System.Xml.XmlDocument
        $xml.LoadXml($rawXml)
    } catch [System.Xml.XmlException] {
        Add-Finding -Severity "BLOCK" -Rule "well-formed-xml" -File $relManifest `
            -Detail "Not well-formed: $($_.Exception.Message)"
        continue
    }

    $controlNode = $xml.SelectSingleNode("//control")
    if (-not $controlNode) {
        Add-Finding -Severity "BLOCK" -Rule "control-element" -File $relManifest -Detail "No <control> element found."
        continue
    }

    $controlType = $controlNode.GetAttribute("control-type")

    # 2. Resource paths resolve ------------------------------------------
    $resourcesNode = $controlNode.SelectSingleNode("resources")
    $allManifestKeys = New-Object System.Collections.Generic.List[string]
    $resxRelativePaths = New-Object System.Collections.Generic.List[string]
    $platformLibraries = New-Object System.Collections.Generic.List[object]

    if ($resourcesNode) {
        foreach ($childType in @("code", "css", "resx", "img")) {
            foreach ($node in $resourcesNode.SelectNodes($childType)) {
                $p = $node.GetAttribute("path")
                if (-not $p) {
                    Add-Finding -Severity "BLOCK" -Rule "resource-missing-path" -File $relManifest `
                        -Detail "A <$childType> resource element has no path attribute."
                    continue
                }
                $full = Join-Path $manifestDir $p
                if (-not (Test-Path -LiteralPath $full)) {
                    Add-Finding -Severity "BLOCK" -Rule "resource-path-missing" -File $relManifest `
                        -Detail "<$childType path=`"$p`"> does not resolve to an existing file (expected at $full)."
                } elseif ($childType -eq "resx") {
                    $resxRelativePaths.Add($p) | Out-Null
                }
            }
        }
        foreach ($plNode in $resourcesNode.SelectNodes("platform-library")) {
            $platformLibraries.Add([PSCustomObject]@{
                name    = $plNode.GetAttribute("name")
                version = $plNode.GetAttribute("version")
            }) | Out-Null
        }
    } else {
        Add-Finding -Severity "WARN" -Rule "no-resources-block" -File $relManifest -Detail "No <resources> element found."
    }

    # 3/4. Localization key cross-check -----------------------------------
    $keyAttrNames = @("display-name-key", "description-key")
    $manifestKeyNodes = $controlNode.SelectNodes(".//*")
    foreach ($node in $manifestKeyNodes) {
        foreach ($attrName in $keyAttrNames) {
            $val = $node.GetAttribute($attrName)
            if ($val) { $allManifestKeys.Add($val) | Out-Null }
        }
    }
    # also the control element's own keys
    foreach ($attrName in $keyAttrNames) {
        $val = $controlNode.GetAttribute($attrName)
        if ($val) { $allManifestKeys.Add($val) | Out-Null }
    }
    $allManifestKeys = $allManifestKeys | Select-Object -Unique

    $resxKeysByFile = @{}
    $resxParseFailed = New-Object System.Collections.Generic.List[string]
    foreach ($resxRel in $resxRelativePaths) {
        $resxFull = Join-Path $manifestDir $resxRel
        $keys = New-Object System.Collections.Generic.List[string]
        try {
            [xml]$resxXml = Get-Content -LiteralPath $resxFull -Raw
            foreach ($dataNode in $resxXml.SelectNodes("//data")) {
                $n = $dataNode.GetAttribute("name")
                if ($n) { $keys.Add($n) | Out-Null }
            }
            $resxKeysByFile[$resxRel] = $keys
        } catch {
            Add-Finding -Severity "BLOCK" -Rule "resx-not-well-formed" -File $resxRel -Detail "Could not parse as XML: $($_.Exception.Message)"
            $resxParseFailed.Add($resxRel) | Out-Null
            # Deliberately not added to $resxKeysByFile: a file that failed
            # to parse has no known key list, so it must not participate in
            # the missing/unused cross-check below -- otherwise every key
            # in every OTHER file gets falsely reported as missing from
            # this one on top of the real parse-error finding.
        }
    }
    # Cross-check only against RESX files that actually parsed.
    $parsedResxPaths = $resxRelativePaths | Where-Object { $resxParseFailed -notcontains $_ }

    if ($resxRelativePaths.Count -eq 0 -and $allManifestKeys.Count -gt 0) {
        Add-Finding -Severity "BLOCK" -Rule "resx-missing-entirely" -File $relManifest `
            -Detail "Manifest references $($allManifestKeys.Count) localization key(s) but no <resx> resource is declared."
    } elseif ($parsedResxPaths.Count -gt 0) {
        foreach ($key in $allManifestKeys) {
            $missingFrom = @()
            foreach ($resxRel in $parsedResxPaths) {
                if ($resxKeysByFile[$resxRel] -notcontains $key) { $missingFrom += $resxRel }
            }
            if ($missingFrom.Count -eq $parsedResxPaths.Count) {
                Add-Finding -Severity "BLOCK" -Rule "resx-key-missing" -File $relManifest `
                    -Detail "Localization key '$key' is missing from every parsed RESX file ($($parsedResxPaths -join ', '))."
            } elseif ($missingFrom.Count -gt 0) {
                Add-Finding -Severity "WARN" -Rule "resx-key-missing-partial" -File $relManifest `
                    -Detail "Localization key '$key' exists in at least one RESX file but is missing from: $($missingFrom -join ', ') -- likely an incomplete translation rather than a defect."
            }
        }
        foreach ($resxRel in $parsedResxPaths) {
            foreach ($resxKey in $resxKeysByFile[$resxRel]) {
                if ($allManifestKeys -notcontains $resxKey) {
                    Add-Finding -Severity "WARN" -Rule "resx-key-unused" -File $resxRel `
                        -Detail "RESX key '$resxKey' is not referenced by any *-key attribute in the manifest (dead string, or a typo in the manifest)."
                }
            }
        }
    }

    # 5. Property name uniqueness and placeholder detection -------------
    $propertyNames = New-Object System.Collections.Generic.List[string]
    $propertyUsageByName = @{}
    foreach ($propNode in $controlNode.SelectNodes("property")) {
        $pname = $propNode.GetAttribute("name")
        if (-not $pname) {
            Add-Finding -Severity "BLOCK" -Rule "property-missing-name" -File $relManifest -Detail "A <property> element has no name attribute."
            continue
        }
        if ($propertyNames -contains $pname) {
            Add-Finding -Severity "BLOCK" -Rule "property-name-duplicate" -File $relManifest -Detail "Property name '$pname' is declared more than once."
        }
        $propertyNames.Add($pname) | Out-Null
        $propertyUsageByName[$pname] = $propNode.GetAttribute("usage")

        if ($placeholderNames -contains $pname) {
            Add-Finding -Severity "WARN" -Rule "property-placeholder-name" -File $relManifest `
                -Detail "Property name '$pname' looks like an un-renamed scaffold placeholder."
        }
        if ($pname -cmatch '^[A-Z]' -or $pname -match '[^a-zA-Z0-9]') {
            Add-Finding -Severity "WARN" -Rule "property-not-camelcase" -File $relManifest `
                -Detail "Property name '$pname' does not look like camelCase."
        }
    }

    # 6. control-type vs platform-library consistency ---------------------
    $isVirtual = ($controlType -eq "virtual")
    if ($isVirtual -and $platformLibraries.Count -eq 0) {
        Add-Finding -Severity "WARN" -Rule "virtual-without-platform-library" -File $relManifest `
            -Detail "control-type is 'virtual' but no <platform-library> entries are declared. Confirm this is intentional before proposing a manifest change."
    }
    if (-not $isVirtual -and $platformLibraries.Count -gt 0) {
        Add-Finding -Severity "WARN" -Rule "standard-with-platform-library" -File $relManifest `
            -Detail "control-type is '$controlType' (not virtual) but <platform-library> entries are declared: $(($platformLibraries | ForEach-Object { $_.name }) -join ', '). Do not add platform-library elements to standard controls."
    }

    # 7. ManifestTypes.d.ts cross-check ------------------------------------
    # Checks IInputs and IOutputs as separate interface bodies, per plan
    # §21.4 item 7: every property must appear in IInputs, and every
    # bound/output property must additionally appear in IOutputs.
    $manifestTypesPath = Join-Path $manifestDir "generated\ManifestTypes.d.ts"
    if (Test-Path -LiteralPath $manifestTypesPath) {
        $typesContent = Get-Content -LiteralPath $manifestTypesPath -Raw

        $inputsMatch = [regex]::Match($typesContent, 'interface\s+IInputs\s*\{([^}]*)\}')
        $outputsMatch = [regex]::Match($typesContent, 'interface\s+IOutputs\s*\{([^}]*)\}')

        if (-not $inputsMatch.Success) {
            Add-Finding -Severity "WARN" -Rule "manifesttypes-out-of-date" -File "generated\ManifestTypes.d.ts" `
                -Detail "Could not locate an 'IInputs' interface in generated\ManifestTypes.d.ts. Run 'npm run refreshTypes' if that script exists -- do not hand-edit the generated file."
        }
        if (-not $outputsMatch.Success) {
            Add-Finding -Severity "WARN" -Rule "manifesttypes-out-of-date" -File "generated\ManifestTypes.d.ts" `
                -Detail "Could not locate an 'IOutputs' interface in generated\ManifestTypes.d.ts. Run 'npm run refreshTypes' if that script exists -- do not hand-edit the generated file."
        }

        foreach ($pname in $propertyNames) {
            if ($inputsMatch.Success -and ($inputsMatch.Groups[1].Value -notmatch "(?m)^\s*$([regex]::Escape($pname))\??\s*:")) {
                Add-Finding -Severity "WARN" -Rule "manifesttypes-out-of-date" -File "generated\ManifestTypes.d.ts" `
                    -Detail "Property '$pname' is declared in the manifest but not found in IInputs in generated\ManifestTypes.d.ts. Run 'npm run refreshTypes' if that script exists -- do not hand-edit the generated file."
            }

            $usage = $propertyUsageByName[$pname]
            if (($usage -eq "bound" -or $usage -eq "output") -and $outputsMatch.Success) {
                if ($outputsMatch.Groups[1].Value -notmatch "(?m)^\s*$([regex]::Escape($pname))\??\s*:") {
                    Add-Finding -Severity "WARN" -Rule "manifesttypes-out-of-date" -File "generated\ManifestTypes.d.ts" `
                        -Detail "Property '$pname' has usage='$usage' but is not found in IOutputs in generated\ManifestTypes.d.ts. Run 'npm run refreshTypes' if that script exists -- do not hand-edit the generated file."
                }
            }
        }
    }

    # 8. feature-usage optional-feature reminder ---------------------------
    $featureUsageNode = $controlNode.SelectSingleNode("feature-usage")
    if ($featureUsageNode) {
        foreach ($featNode in $featureUsageNode.SelectNodes("uses-feature")) {
            $fname = $featNode.GetAttribute("name")
            $frequired = $featNode.GetAttribute("required")
            if ($frequired -eq "false") {
                Add-Finding -Severity "INFO" -Rule "optional-feature-fallback-reminder" -File $relManifest `
                    -Detail "Feature '$fname' is declared required=`"false`". This script cannot verify the code -- confirm a runtime availability check and fallback exist before shipping."
            }
        }
    }

    # 9. Duplicate React/Fluent bundling heuristic --------------------------
    # Walk upward from the manifest looking for package.json, but never
    # above $root -- otherwise, on a manifest with no package.json anywhere
    # under the scanned project, this can escape onto an unrelated parent
    # directory's package.json and produce a bogus duplicate-bundling
    # finding against a project that has nothing to do with this control.
    $projectRoot = $manifestDir
    while ($projectRoot -and $projectRoot.Length -ge $root.Length -and
           -not (Test-Path -LiteralPath (Join-Path $projectRoot "package.json"))) {
        if ($projectRoot -eq $root) { break }
        $parent = Split-Path -Path $projectRoot -Parent
        if (-not $parent -or $parent -eq $projectRoot -or $parent.Length -lt $root.Length) { break }
        $projectRoot = $parent
    }
    $pkgJsonPath = Join-Path $projectRoot "package.json"
    if ($projectRoot.Length -ge $root.Length -and (Test-Path -LiteralPath $pkgJsonPath)) {
        try {
            $pkg = Get-Content -LiteralPath $pkgJsonPath -Raw | ConvertFrom-Json
            $depNames = @()
            if ($pkg.dependencies) { $depNames += $pkg.dependencies.PSObject.Properties.Name }
            foreach ($pl in $platformLibraries) {
                $plNameLower = ("" + $pl.name).ToLowerInvariant()
                $matchingDep = $depNames | Where-Object { $_.ToLowerInvariant() -like "*$plNameLower*" }
                if ($matchingDep) {
                    Add-Finding -Severity "WARN" -Rule "duplicate-bundling" -File $relManifest `
                        -Detail "'$($pl.name)' is declared as a platform-library AND present in package.json dependencies ($($matchingDep -join ', ')). This risks bundling a duplicate copy at runtime."
                }
            }
        } catch {
            # package.json unparsable -- already reported by inspect-pcf-project.ps1; do not duplicate here.
        }
    }
}

# --- Output ------------------------------------------------------------
if ($Json) {
    $findings | ConvertTo-Json -Depth 5
} else {
    $blocks = $findings | Where-Object { $_.Severity -eq "BLOCK" }
    $warns  = $findings | Where-Object { $_.Severity -eq "WARN" }
    $infos  = $findings | Where-Object { $_.Severity -eq "INFO" }

    if ($blocks) {
        Write-Output "BLOCK:"
        foreach ($f in $blocks) { Write-Output "  [$($f.Rule)] $($f.File): $($f.Detail)" }
        Write-Output ""
    }
    if ($warns) {
        Write-Output "WARN:"
        foreach ($f in $warns) { Write-Output "  [$($f.Rule)] $($f.File): $($f.Detail)" }
        Write-Output ""
    }
    if ($infos) {
        Write-Output "INFO:"
        foreach ($f in $infos) { Write-Output "  [$($f.Rule)] $($f.File): $($f.Detail)" }
        Write-Output ""
    }
    if (-not $blocks -and -not $warns -and -not $infos) {
        Write-Output "No findings."
    }
}

if ($findings | Where-Object { $_.Severity -eq "BLOCK" }) {
    exit 2
} elseif ($FailOnWarn -and ($findings | Where-Object { $_.Severity -eq "WARN" })) {
    exit 1
} else {
    exit 0
}

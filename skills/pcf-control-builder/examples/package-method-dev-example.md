# Worked example: package method for a development target (explicit override)

Picks up from S10 — assumes S1-S9 already happened (requirement discovery,
prerequisites, scaffold, React design approved at Gate A, manifest approved
at Gate B, integration, local validation). See
[field-control-example.md](field-control-example.md) or
[dataset-control-example.md](dataset-control-example.md) for how those
stages look; this file only covers what's different when a **development**
target explicitly asks for the full package method instead of the
`pac pcf push` default. All values are placeholders — this shows sequence
and shape, not copy-paste content.

## Why this example exists

The default for a `development`-classified target is `pac pcf push` (see
[field-control-example.md § S10](field-control-example.md#s10-packaging)).
Sometimes a user wants the full package method in dev anyway — e.g.
building toward a managed artifact meant for later promotion, or wanting a
source-controlled solution project from day one. That's a valid override
(see
[deployment-and-alm.md § Deployment method comes first](../references/deployment-and-alm.md#deployment-method-comes-first)),
and it changes the whole S10-S13 shape.

## S10: deployment preparation

**Worksheet W8 first.** Environment `https://fabrikam-dev.crm5.dynamics.com`,
classification `development`. `pac auth list` checked first — an existing
profile targeting that environment is reused if one exists; `pac auth
create --environment "https://fabrikam-dev.crm5.dynamics.com"` only if none
does (interactive sign-in or `--deviceCode`, never `--password`). `pac auth
who` confirms the resolved environment matches.

**Deployment method — recorded as an explicit override.** Classification
`development` would normally suggest `pac pcf push`. The user asks for the
full package method instead; this is recorded in spec §16, not silently
swapped back to the default.

**Worksheet W7, package shape:** publisher display name (`Fabrikam`),
publisher prefix (`fbk`), solution unique name (`FabrikamUrlControls` —
decided *now*, before any folder gets created, not fixed up afterward),
solution display name, solution version (4-segment, e.g. `1.0.0.0`),
managed or unmanaged (asked explicitly — unmanaged suggested for a first
dev push, with that basis stated, but it's the user's call either way),
build path, whether to run the Power Apps Checker, whether to publish
changes on import. Control-version row: this is the control's first-ever
publish, so it ships whatever's currently in the manifest (`1.0.0`)
unchanged — the per-publish bump only starts on the second deployment.

**Create the solution project, named correctly from the start** — not in a
literally-named `Solutions` folder, which would just have to be renamed
later:

```powershell
New-Item -ItemType Directory -Path "solution\FabrikamUrlControls" -Force
Set-Location "solution\FabrikamUrlControls"
pac solution init --publisher-name "Fabrikam" --publisher-prefix "fbk"
pac solution add-reference --path "..\..\FabrikamUrlControl"
```

**Build** — path chosen from what prerequisites actually found (S2), never
assumed:

```powershell
# preferred when the .NET SDK is present
dotnet build --configuration Release
```
```powershell
# only if MSBuild is the available option — discovered, never a hard-coded VS path
$msbuild = & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -products * -requires Microsoft.Component.MSBuild -latest -find "MSBuild\**\Bin\MSBuild.exe"
& $msbuild /t:restore
& $msbuild /p:configuration=Release
```

**Discover the artifact** by enumerating `bin\**\*.zip` under both `Debug`
and `Release`, reporting the real name, size, and timestamp — never
assuming `bin\Debug\<ProjectName>.zip`. If the solution's name or version
inside the artifact isn't right, the fix is editing `Solution.xml` (or
re-running `pac solution init`/`add-reference` with corrected values) and
rebuilding — **never renaming the zip or opening it up to hand-edit its
contents.** That anti-pattern only ever comes up when the unique name
wasn't decided correctly at `pac solution init` time — which is why it's
decided in Worksheet W7, before step one of this section.

## S11: no Gate C for development

The *method* changed (package instead of push), but the *classification*
didn't — still `development` — and per
[deployment-and-alm.md § Development deployments run without a
confirmation gate](../references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate)
that means **no Gate C at all, regardless of method.** No readiness
report, no typed string — this is true even though it's the first time
`https://fabrikam-dev.crm5.dynamics.com` has ever been used, because
classification alone decides this, not which method or whether it's a
repeat. One heads-up line, then the import runs:

> Importing FabrikamUrlControls v1.0.0.0 (control v1.0.0) to
> https://fabrikam-dev.crm5.dynamics.com (development, no confirmation
> required)...

## S12: remote operation

The command runs immediately after the heads-up line above — no reply is
waited for:

```powershell
pac solution import --path "<discovered-artifact-path>" --environment "https://fabrikam-dev.crm5.dynamics.com"
```

`--publish-changes` only if it was explicitly approved on the W7 row; no
other import modifier (`--force-overwrite`, `--skip-dependency-check`, etc.)
without its own separate justification and confirmation.

## S13: verification

`pac solution list` confirms `FabrikamUrlControls` now exists in the
environment at the expected version; `pac auth who` re-confirms the
environment; any import warnings reported verbatim; manual maker-portal
step noted (the control still needs to be added to a form and the form
published — import alone doesn't do that); smoke-test checklist derived
from the Gate A approved states; spec §19 deployment-history row appended
(recording control version `1.0.0`, method `package`).

## On a later redeploy

`https://fabrikam-dev.crm5.dynamics.com` is now on record in spec §17 as
`development`, and the chosen method (`package`, the explicit override)
is on record in spec §16 — so per
[deployment-and-alm.md § Development deployments run without a
confirmation gate](../references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate),
**no W8, no W7, no Gate C**, regardless of whether this happens later in
the same chat or in a brand-new session days later. What actually runs:

- `pac auth who` verifies the resolved environment still matches
  `https://fabrikam-dev.crm5.dynamics.com` — silently, unless it doesn't
  match, in which case this stops and asks.
- The control-version bump applies automatically: `1.0.0` → `1.0.1`.
- The solution is rebuilt (`dotnet build --configuration Release`, or the
  discovered MSBuild path), the artifact is rediscovered under `bin\**\*.zip`,
  and — because the method on record is `package`, not `push` — a new
  solution build/revision number is computed for `Solution.xml` the same
  way it would be proposed on a worksheet elsewhere, just without pausing
  to ask.
- A one-line heads-up is shown, then the import runs immediately:

  > Importing FabrikamUrlControls v1.0.0 (control v1.0.1) to
  > https://fabrikam-dev.crm5.dynamics.com (development, no confirmation
  > required)...

- The full [S13 verification](#s13-verification) report — `pac solution
  list` confirmation, warnings, smoke-test checklist, spec §19 row — runs
  exactly as it did on the first import, so the user still sees the real
  outcome.

If the user wants this specific target back under full confirmation, they
can say so explicitly ("always confirm before deploying to Fabrikam dev")
— recorded in spec §16 as a per-environment override, after which this
target's S10 runs the full W8/W7/Gate C flow again, indefinitely. Nothing
in this section ever applies to `pac solution publish`
(publish-all-customizations), which always requires its own separate
confirmation regardless of classification.

# Troubleshooting

## Table of contents
- [The evidence rule](#the-evidence-rule)
- [T1 -- npm dependency resolution error](#t1--npm-dependency-resolution-error)
- [T2 -- node/npm not recognized](#t2--nodenpm-not-recognized)
- [T3 -- pac not found](#t3--pac-not-found)
- [T4 -- wrong Node version](#t4--wrong-node-version)
- [T5 -- missing .NET SDK / MSBuild](#t5--missing-net-sdk--msbuild)
- [T6 -- invalid namespace / control name](#t6--invalid-namespace--control-name)
- [T7 -- invalid manifest XML](#t7--invalid-manifest-xml)
- [T8 -- manifest element unsupported for the target host](#t8--manifest-element-unsupported-for-the-target-host)
- [T9 -- missing RESX key](#t9--missing-resx-key)
- [T10 -- missing resource path](#t10--missing-resource-path)
- [T11 -- property missing from IInputs/IOutputs](#t11--property-missing-from-iinputsioutputs)
- [T12 -- refreshTypes fails](#t12--refreshtypes-fails)
- [T13 -- tsconfig "No inputs were found"](#t13--tsconfig-no-inputs-were-found)
- [T14 -- ESLint configuration error](#t14--eslint-configuration-error)
- [T15 -- React type conflicts](#t15--react-type-conflicts)
- [T16 -- duplicate React/Fluent bundling](#t16--duplicate-reactfluent-bundling)
- [T17 -- build errors](#t17--build-errors)
- [T18/T19 -- PCF test harness limitations](#t18t19--pcf-test-harness-limitations)
- [T20 -- auth-profile mismatch](#t20--auth-profile-mismatch)
- [T21 -- wrong publisher prefix](#t21--wrong-publisher-prefix)
- [T22 -- missing solution reference](#t22--missing-solution-reference)
- [T23 -- managed/unmanaged confusion](#t23--managedunmanaged-confusion)
- [T24 -- ambiguous project names](#t24--ambiguous-project-names)
- [T25 -- solution import dependency failure](#t25--solution-import-dependency-failure)
- [T26 -- version conflict on import](#t26--version-conflict-on-import)
- [T27 -- control deployed but not visible in the maker/app](#t27--control-deployed-but-not-visible-in-the-makerapp)
- [T28 -- preview renders blank / no elements on the page](#t28--preview-renders-blank--no-elements-on-the-page)
- [Escalation](#escalation)

## The evidence rule

**No fix without output.** Every branch here follows: reproduce -> capture
the *actual* error text -> identify the smallest cause consistent with that
text -> propose one targeted change -> apply -> re-run the same command ->
compare. If the error text was not captured, the first action is to
capture it, not to guess.

Banned as first moves: shotgun fixes (`rm -rf node_modules` before reading
the error), speculative version pinning, creating config files that were
never shown to be missing, and "try this, it usually works."

Each entry below: **Symptom** -> **Evidence to collect** -> **Likely
causes, ordered** -> **Targeted fix** -> **Verify** -> **Anti-pattern**.

---

### T1 — npm dependency resolution error

**Symptom:** `npm install`/`npm ci` fails with `ERESOLVE` or a peer-dependency
conflict.
**Evidence:** full npm output including the peer-dependency tree;
`package-lock.json` presence and its `lockfileVersion`.
**Likely causes:** (1) an intentional dependency change conflicts with an
existing peer range, (2) the lockfile is out of sync with `package.json`,
(3) two packages declare incompatible peer ranges for the same dependency.
**Fix:** identify the specific conflicting peer from the tree, and change
only that. Do not reach for `--legacy-peer-deps`/`--force` before reading
which peer actually conflicts.
**Verify:** re-run the same install command; confirm no `ERESOLVE` block
remains.
**Anti-pattern:** `--force`, `--legacy-peer-deps`, or deleting
`node_modules` as an opening move.

### T2 — node/npm not recognized

**Symptom:** `node`/`npm` "is not recognized as an internal or external
command."
**Evidence:** `where.exe node`; standard install-dir probes; version-manager
directory check (`%APPDATA%\nvm`, etc.) — see
[`scripts/check-prerequisites.ps1`](../scripts/check-prerequisites.ps1).
**Likely causes:** (1) Node genuinely not installed, (2) installed but a
new shell hasn't picked up PATH yet, (3) a version manager has it
shell-scoped and the active shell/profile differs.
**Fix:** report the actual finding; if a version manager is present, note
that the active version is shell-scoped. Never install Node automatically.
**Verify:** re-run `check-prerequisites.ps1` in the shell that will
actually be used for the rest of the session.
**Anti-pattern:** assuming a broken install when it's simply a new shell.

### T3 — pac not found

**Symptom:** `pac` "is not recognized," or resolves to an unexpected
binary.
**Evidence:** `(Get-Command pac).Source`; `~/.vscode/extensions` scan for
`*powerplatform*`/`*isvexptools*`.
**Likely causes:** (1) PAC CLI genuinely not installed, (2) it's only
available via the VS Code extension's bundled copy, (3) two installs
coexist and PATH resolves the wrong one.
**Fix:** report which `pac` (if any) is on PATH and whether the VS Code
extension ships its own. Recommend Power Platform Tools for VS Code as the
preferred channel, the Windows MSI as a fallback. Never install a second
copy alongside an existing one without telling the user both now exist.
**Verify:** `pac --version` plus `(Get-Command pac).Source` together.
**Anti-pattern:** installing a second `pac` "to be safe."

### T4 — wrong Node version

**Symptom:** an install or build fails with an engine/version complaint, or
succeeds but behaves unexpectedly.
**Evidence:** `node --version` vs `package.json` `engines.node` vs whatever
version the project's pcf-scripts actually requires (read from the
project, not memory).
**Likely causes:** a version-manager default differs from what this
project needs.
**Fix:** switch the active Node version for this project/shell via the
existing version manager. Do not upgrade Node globally to fix one project.
**Verify:** `node --version` matches the `engines` range; re-run the
failing command.
**Anti-pattern:** a global Node upgrade to satisfy one project's range.

### T5 — missing .NET SDK / MSBuild

**Symptom:** `dotnet build` or `msbuild` not found; solution packaging or
`pac pcf push` fails to build its temporary wrapper.
**Evidence:** `dotnet --list-sdks`; `vswhere -products * -requires
Microsoft.Component.MSBuild -latest -find "MSBuild\**\Bin\MSBuild.exe"`.
**Likely causes:** neither is installed, or MSBuild exists but isn't on
PATH (common — Visual Studio does not put it there by default).
**Fix:** prefer `dotnet build` when the SDK is present. When only MSBuild
is available, use the `vswhere`-discovered path or a Developer PowerShell
for VS. Never hard-code a Visual Studio version/drive/edition path — this
skill's own evidence base found MSBuild on a non-default drive under a
non-default VS version on its reference workstation.
**Verify:** the build command referenced above completes; re-check with
`check-prerequisites.ps1`.
**Anti-pattern:** hard-coding `C:\Program Files\Microsoft Visual
Studio\2022\Enterprise\...`; asking the user to edit the machine PATH.

### T6 — invalid namespace / control name

**Symptom:** `pac pcf init` rejects the namespace or name.
**Evidence:** the CLI's own rejection text.
**Likely causes:** invalid characters, reserved words, or a value pac's
current version constrains differently than expected.
**Fix:** quote the CLI's error verbatim to the user and re-propose a value
that satisfies it — do not guess the rule independently.
**Verify:** re-run `pac pcf init` with the corrected value.
**Anti-pattern:** guessing the naming rule instead of reading the CLI's
own message.

### T7 — invalid manifest XML

**Symptom:** a build or `refreshTypes` fails citing the manifest.
**Evidence:** the build output's line/column; confirm with
[`scripts/validate-pcf-project.ps1`](../scripts/validate-pcf-project.ps1)
(`well-formed-xml` finding, which reports line/position).
**Likely causes:** an unclosed tag, a bad attribute, an edit made without
re-reading the file first.
**Fix:** correct only the specific malformed section.
**Verify:** re-run `validate-pcf-project.ps1`; confirm no `well-formed-xml`
finding remains.
**Anti-pattern:** rewriting the whole manifest to fix one attribute.

### T8 — manifest element unsupported for the target host

**Symptom:** an element accepted by the schema is rejected or ignored by a
specific host (model-driven / canvas / custom page).
**Evidence:** the host + element pair; current official Microsoft
documentation for that pair — see
[official-source-policy.md](official-source-policy.md#where-to-verify-hosttypeelement-support).
**Likely causes:** the element genuinely isn't supported on that host, or
support differs from what was assumed for a different host.
**Fix:** confirm via current docs before assuming; if unsupported, remove
the element or note it as a documented host limitation in the manifest
proposal's compatibility-warnings section.
**Verify:** the host accepts the manifest in the local harness at minimum,
ideally after a controlled environment test.
**Anti-pattern:** assuming canvas-app support implies model-driven support,
or vice versa.

### T9 — missing RESX key

**Symptom:** a display/description string renders blank or shows the raw
key.
**Evidence:** `validate-pcf-project.ps1`'s `resx-key-missing` finding,
which names the exact key and the RESX file(s) checked.
**Likely causes:** the manifest references a key that was never added to
RESX, or added to the wrong RESX file/locale.
**Fix:** **add the missing string** to the RESX file.
**Verify:** re-run `validate-pcf-project.ps1`; the finding clears.
**Anti-pattern:** deleting the manifest's `*-key` reference instead of
adding the string.

### T10 — missing resource path

**Symptom:** a build fails citing a missing file, or a resource silently
doesn't load.
**Evidence:** `validate-pcf-project.ps1`'s `resource-path-missing` finding,
which states the expected full path.
**Likely causes:** the file was never created, was moved, or the manifest
path has a typo.
**Fix:** create the file at the declared path, or correct the path to
where the real file lives — verify the target actually exists before
changing the manifest.
**Verify:** re-run `validate-pcf-project.ps1`.
**Anti-pattern:** editing the path to a second guess without checking it
exists either.

### T11 — property missing from IInputs/IOutputs

**Symptom:** TypeScript can't find a manifest property on `context.parameters`
or on `IOutputs`.
**Evidence:** whether `npm run refreshTypes` has run since the last
manifest edit; `validate-pcf-project.ps1`'s `manifesttypes-out-of-date`
finding when `generated/ManifestTypes.d.ts` exists.
**Likely causes:** the manifest was edited and types were never
regenerated.
**Fix:** run `npm run refreshTypes` (only if that script exists).
**Verify:** the property now appears in `generated/ManifestTypes.d.ts`;
TypeScript error clears.
**Anti-pattern:** hand-editing `ManifestTypes.d.ts` instead of
regenerating it.

### T12 — refreshTypes fails

**Symptom:** `npm run refreshTypes` exits non-zero.
**Evidence:** the full script output; manifest validity (T7); confirm the
script actually exists in `package.json` before running it.
**Likely causes:** malformed manifest XML, or the script doesn't exist in
this project's scaffold version.
**Fix:** resolve the underlying manifest issue first (T7/T9/T10), then
retry.
**Verify:** the script completes and `generated/ManifestTypes.d.ts`
updates.
**Anti-pattern:** running a script that isn't in `package.json`.

### T13 — tsconfig "No inputs were found"

**Symptom:** `tsc` reports no matching input files.
**Evidence:** the resolved `include`/`exclude` after following `extends`;
the actual folder layout.
**Likely causes:** a folder was moved/renamed without updating
`include`/`exclude`, or a speculative path prefix was added that doesn't
match the real structure.
**Fix:** correct `include`/`exclude` to match the real layout, following
the existing `extends` chain rather than replacing it.
**Verify:** `tsc --noEmit` (or the project's type-check command) finds
files.
**Anti-pattern:** prefixing paths with the project folder name without
checking whether the structure actually requires it.

### T14 — ESLint configuration error

**Symptom:** `npm run lint` fails to even start, citing config resolution.
**Evidence:** which config style the project actually uses (legacy
`.eslintrc*`, flat `eslint.config.*`, pcf-scripts-provided, or none —
[`scripts/inspect-pcf-project.ps1`](../scripts/inspect-pcf-project.ps1)
reports it); the exact ESLint + parser versions from the error.
**Likely causes:** a peer-version mismatch, or a config file created for
the wrong config style.
**Fix:** match the detected style; read the actual peer requirement from
the error rather than assuming `@typescript-eslint/parser` must share
ESLint's major version.
**Verify:** `npm run lint` runs (pass or fail on content, not on config
resolution).
**Anti-pattern:** blindly creating `.eslintrc.json` in a project that uses
flat config, or vice versa.

### T15 — React type conflicts

**Symptom:** TypeScript reports incompatible JSX/React types from two
different `@types/react` copies.
**Evidence:** `npm ls @types/react` showing duplicate versions.
**Likely causes:** a dependency install introduced a second copy instead of
deduplicating against the existing one.
**Fix:** identify which install introduced the duplicate and resolve at
that layer (not by deleting `@types/react` from an arbitrary location).
**Verify:** `npm ls @types/react` shows a single resolved version.
**Anti-pattern:** deleting `@types/react` from one place at random.

### T16 — duplicate React/Fluent bundling

**Symptom:** the built bundle is unexpectedly large, or the control renders
with two independent React instances (symptoms like context not
propagating, hooks behaving oddly across component boundaries).
**Evidence:** bundle output size/contents; manifest `platform-library`
entries vs `package.json` dependencies —
[`scripts/validate-pcf-project.ps1`](../scripts/validate-pcf-project.ps1)'s
`duplicate-bundling` finding flags this automatically.
**Likely causes:** React or Fluent is both declared as a `platform-library`
(host-supplied) and present in `package.json` `dependencies` (bundled),
producing two copies at runtime.
**Fix:** remove the bundled dependency and rely on the platform library, or
vice versa — a deliberate choice, not both.
**Verify:** re-run `validate-pcf-project.ps1`; the finding clears.
**Anti-pattern:** removing the `platform-library` declaration just to
silence the warning without addressing the actual duplicate.

### T17 — build errors

**Symptom:** `npm run build` fails.
**Evidence:** full build output; the **first** error in the output.
**Likely causes:** varies — this is where T7/T9/T10/T11/T13/T15/T16 often
surface as this generic symptom.
**Fix:** fix the first error, rebuild, re-read the new first error. Do not
attempt to fix errors further down the output before the first one is
resolved (later errors are often downstream of the first).
**Verify:** `npm run build` exits 0.
**Anti-pattern:** fixing later errors before the first one, which can
mask or duplicate work.

### T18/T19 — PCF test harness limitations

**Symptom:** `context.webAPI` (or another platform API) returns
`undefined` or behaves unexpectedly only inside `npm start`'s harness.
**Evidence:** which specific API returned undefined, and the exact call
context.
**Likely causes:** the local harness stubs or omits several platform
APIs — this is a harness limitation, not necessarily a control defect. See
[build-and-testing.md § Three testing layers](build-and-testing.md#three-distinct-testing-layers).
**Fix:** do not rewrite otherwise-correct code to work around the harness.
Note the limitation, and recommend environment-integrated testing (Layer 3)
for that specific code path.
**Verify:** the same code path is exercised in an approved deployment/test
environment when one becomes available.
**Anti-pattern:** reporting the control as broken based solely on harness
behavior, or refactoring correct WebAPI code to satisfy the harness.

### T20 — auth-profile mismatch

**Symptom:** `pac auth who` shows a different environment than the one
requested.
**Evidence:** `pac auth list` + `pac auth who` output, compared line by
line against the requested environment (Worksheet W8).
**Likely causes:** the wrong profile is active, or the requested
environment was never authenticated against on this machine.
**Fix:** `pac auth select` to the correct existing profile, or create one
if genuinely none exists — never create a second profile for an
environment that already has one.
**Verify:** re-run `pac auth who`; confirm it now matches the request.
**Anti-pattern:** creating another profile instead of selecting the
correct existing one.

### T21 — wrong publisher prefix

**Symptom:** push or import fails citing a publisher/prefix problem.
**Evidence:** the prefix used vs the publisher that actually exists in the
target environment.
**Likely causes:** the prefix was guessed rather than confirmed against the
environment.
**Fix:** confirm the correct prefix (via the environment, once reachable,
or from the user) and use that value consistently.
**Verify:** re-run the push/import.
**Anti-pattern:** changing the prefix repeatedly until something succeeds,
without confirming which one is actually correct.

### T22 — missing solution reference

**Symptom:** the solution project doesn't include the PCF control when
built.
**Evidence:** `.cdsproj` project references (`inspect-pcf-project.ps1`
reports these).
**Likely causes:** `pac solution add-reference` was never run, or was run
against the wrong path.
**Fix:** run `pac solution add-reference --path <pcf-project-path>` from
the solution project directory.
**Verify:** the `.cdsproj` now references the PCF project; rebuild and
confirm the control is in the artifact.
**Anti-pattern:** re-running `pac solution init` over an existing project
to "start fresh."

### T23 — managed/unmanaged confusion

**Symptom:** the wrong package type is imported, or the intended type is
unclear.
**Evidence:** `SolutionPackageType` in the `.cdsproj`; the build
configuration used; the actual artifact produced.
**Likely causes:** `SolutionPackageType` set to `Both` without a clear
choice of which zip to use, or the artifact was renamed at some point.
**Fix:** determine type from the `.cdsproj` setting and the actual build
output — never from a filename that may have been renamed.
**Verify:** the readiness report's package-type field matches the actual
artifact.
**Anti-pattern:** renaming a zip to change its apparent type.

### T24 — ambiguous project names

**Symptom:** confusion about which "UrlLauncher" is meant — the PCF
project, the solution project, or the solution unique name.
**Evidence:** [`scripts/inspect-pcf-project.ps1`](../scripts/inspect-pcf-project.ps1)'s
name-collision warnings.
**Likely causes:** the solution directory/project was named identically to
the PCF project (a documented anti-pattern — see
[deployment-and-alm.md](deployment-and-alm.md#solution-packaging-flow)).
**Fix:** rename one of them to a distinct value; record all four names
(display name, unique name, project name, zip filename) in the spec §15.
**Verify:** re-run `inspect-pcf-project.ps1`; the collision warning clears.
**Anti-pattern:** letting the PCF project and solution project share a
name because it "seemed simpler."

### T25 — solution import dependency failure

**Symptom:** `pac solution import` fails citing a missing dependency.
**Evidence:** the import error's dependency list, in full.
**Likely causes:** a genuinely missing prerequisite component/solution in
the target environment.
**Fix:** identify and resolve the actual missing dependency.
**Verify:** re-run the import.
**Anti-pattern:** reaching for `--skip-dependency-check` as a reflex
instead of resolving the real dependency.

### T26 — version conflict on import

**Symptom:** `pac solution import` reports a version conflict.
**Evidence:** the version already present in the environment vs the
version in the artifact being imported.
**Likely causes:** the artifact wasn't rebuilt after a version bump, or the
environment already has an equal/higher version.
**Fix:** bump the version deliberately and rebuild, or use
`--skip-lower-version` only with explicit user approval and a stated
reason.
**Verify:** re-run the import; confirm the reported version now matches
intent.
**Anti-pattern:** `--force-overwrite` as a reflex instead of understanding
why the versions conflict.

### T27 — control deployed but not visible in the maker/app

**Symptom:** `pac solution import` / `pac pcf push` reported success, but
the control doesn't show up when adding a field/column to a form, or
doesn't render for end users, or isn't offered in the component picker.
**Evidence:** `pac solution list` confirming the solution/version is
actually present in the target environment; whether the solution has been
**published** (an import does not publish automatically unless
`--publish-changes` was explicitly approved on Worksheet W7); which app
type is being tested (model-driven vs. canvas vs. custom page) and whether
that host was the one confirmed in Worksheet W1/W3.
**Likely causes, ordered:**
1. The solution imported but was never published — customizations stay
   pending until publish. Check whether `--publish-changes` was approved;
   if not, that is a separate, explicitly-confirmed operation (see
   [Publish all customizations](deployment-and-alm.md#publish-all-customizations)),
   never run silently as a side effect of troubleshooting.
2. **Deployment alone never places a control on a form or view.** A maker
   still has to open the form/view in the designer, add the field or
   change its control, pick this control from the component list, and
   save/publish the form — see
   [deployment-and-alm.md § Post-deployment verification, step 6](deployment-and-alm.md#post-deployment-verification).
   This is expected behavior, not a defect.
3. For a **canvas app**, code components must be enabled for the
   environment (a maker/admin-portal environment setting, off by default
   in many tenants) — this is a setting the skill cannot check or change
   remotely; confirm with the user whether it's on.
4. Browser/client caching of the old component bundle — ask the user to
   hard-refresh or open a private/incognito window before concluding
   anything is actually broken.
5. The control version genuinely wasn't bumped, so the environment still
   has the previous build — see the version-bump note in
   [Post-deployment verification](deployment-and-alm.md#post-deployment-verification).
**Fix:** work down the ordered list with evidence at each step — confirm
publish state, confirm the manual form-configuration step actually
happened, confirm the environment setting for canvas apps, rule out
caching, then check the version. Do not jump to "the deployment failed"
or start rebuilding the control before these are ruled out.
**Verify:** the control renders in the actual app after the missing step
is completed.
**Anti-pattern:** re-running the import repeatedly, assuming a build
defect, or silently running `pac solution publish` (which affects the
**entire** environment, not just this control) to "see if it helps."

### T28 — preview renders blank / no elements on the page

**Symptom:** the S4 preview loads but the page is empty — no elements, no
error visible in the page itself. Commands may all have exited 0. Often
first reported by the user ("the page has no elements"), which means the
[preview verification loop](react-preview-and-architecture.md#preview-verification-loop-before-gate-a)
was skipped or its checks were not actually looked at.
**Evidence:** the browser console text in full (a minified React error
prints a `react.dev/errors/<n>` URL — decode the number, don't guess);
whether the mount root exists and is empty vs. missing entirely; the
dev-server / `vite build` output; `npm --prefix preview ls react react-dom`
**and** `npm ls react react-dom` in the PCF project, compared.
**Likely causes, ordered:**
1. **Two React copies** — the preview entry and the component resolve
   different `react`/`react-dom` installs across the `preview/` boundary.
   Signature: React error **#321** ("invalid hook call"), or hooks failing
   only for the imported component. This is the default failure of the
   isolated-workspace layout when the dedupe config is missing.
2. **Nothing ever mounted** — `index.html` has no mount element, the id in
   `createRoot(document.getElementById('root'))` doesn't match it, or
   `index.html` never references `main.tsx` via
   `<script type="module" src="/main.tsx">`. Signature: the root is missing
   or empty and the console is clean.
3. **A throw during first render** unmounts the whole tree, leaving an
   empty root — a mock-data field read as `undefined`, a bad import, a
   `null` deref in the component. Signature: an `Uncaught` above the React
   warning; the first error in the console is the real one.
4. **Rendered but invisible** — the scoped CSS collapses the container
   (zero height, `display: none`, a color-on-color state), or the preview
   page renders one state that happens to be the empty state. Signature:
   the root *has* children in the DOM inspector.
5. **Stale build served** — the page being looked at is a previously built
   `preview/dist` or a cached bundle, not the current code.
**Fix:** cause 1 — add `resolve.dedupe: ['react', 'react-dom']` plus the
absolute aliases to `preview/vite.config.ts` (exact config in
[react-preview-and-architecture.md § Isolated preview workspace layout](react-preview-and-architecture.md#isolated-preview-workspace-layout));
deduplicate **only** those two packages. Cause 2 — align the id and the
script tag; do not rewrite the component. Cause 3 — fix the first console
error only, then re-check. Cause 4 — inspect computed styles before
touching TSX. Cause 5 — rebuild and hard-refresh before changing any code.
**Verify:** re-run the same build/dev command, re-run the same DOM check
(root non-empty, expected state sections present), confirm the console is
clean — **and** ask the user to reload and confirm they can see it, per the
verification loop. The branch is not closed by a passing check alone; it is
closed by the user's confirmation.
**Anti-pattern:** asking Gate A over a preview no one has confirmed
renders; copying the component into `preview/` to dodge the resolution
problem; adding every package to `dedupe`; deleting `node_modules` before
reading the console; or presenting a description of the intended UI in
place of a preview that never rendered.

---

## Escalation

If two targeted fixes fail, stop and report: what was tried, what the
output was each time, and what information is missing. Do not continue
iterating silently.

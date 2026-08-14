# Deployment and ALM

## Table of contents
- [Solution packaging flow](#solution-packaging-flow)
- [Release output and versioning](#release-output-and-versioning)
- [Versioning](#versioning)
  - [Control version policy (this skill's default)](#control-version-policy-this-skills-default)
- [Environment selection (Worksheet W8)](#environment-selection-worksheet-w8)
- [Worksheet W7 -- packaging decisions](#worksheet-w7--packaging-decisions)
  - [Deployment method comes first](#deployment-method-comes-first)
  - [Naming the method directly](#naming-the-method-directly)
  - [Development deployments run without a confirmation gate](#development-deployments-run-without-a-confirmation-gate)
  - [W7 -- push method](#w7--push-method)
  - [W7 -- package method](#w7--package-method)
  - [Both methods](#both-methods)
- [Development push](#development-push)
- [Solution import](#solution-import)
- [Publish all customizations](#publish-all-customizations)
- [Gate C -- deployment readiness report](#gate-c--deployment-readiness-report)
- [Post-deployment verification](#post-deployment-verification)
- [Git and filesystem safety](#git-and-filesystem-safety)

All PAC CLI syntax below is the dated snapshot in
[official-source-policy.md](official-source-policy.md#dated-cli-snapshot--re-verify-before-relying-on-it).
Re-verify with `pac <group> <verb> help` before running anything — installed
CLI help wins over this file when they disagree.

## Solution packaging flow

This is the **suggested default method for test/UAT/staging/production
targets** (or a development target that explicitly wants it) — see
[Worksheet W7 § Deployment method comes first](#deployment-method-comes-first).
For a routine development-classified deployment, prefer
[Development push](#development-push) instead.

Name the solution directory after the **intended solution unique name**,
and make sure it differs from the PCF project name — `pac solution init`
has no name-setting flag, so the unique name comes from the directory /
project you create, and a directory literally named `Solutions` produces a
solution literally named `Solutions`.

```powershell
New-Item -ItemType Directory -Path "solution\<SolutionUniqueName>" -Force
Set-Location "solution\<SolutionUniqueName>"
pac solution init --publisher-name "<PublisherName>" --publisher-prefix "<prefix>"
pac solution add-reference --path "..\..\<PcfProjectFolder>"
```

Then build with one path, chosen from what
[`scripts/check-prerequisites.ps1`](../scripts/check-prerequisites.ps1)
actually found — never both, and never a hard-coded MSBuild path:

```powershell
# Preferred when the .NET SDK is present
dotnet build
dotnet build --configuration Release
```

```powershell
# Fallback when only MSBuild is available. Discover the path -- do not
# hard-code a Visual Studio version or drive letter.
$msbuild = & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" `
  -products * -requires Microsoft.Component.MSBuild -latest `
  -find "MSBuild\**\Bin\MSBuild.exe"
& $msbuild /t:restore
& $msbuild /p:configuration=Release
```

A Developer PowerShell for VS also puts MSBuild on PATH for that session —
acceptable as an alternative. Never ask the user to edit the machine-wide
PATH to make MSBuild reachable.

## Release output and versioning

- `Release` configuration for release artifacts.
- `SolutionPackageType` in the `.cdsproj` controls Managed / Unmanaged /
  Both. Read the current value
  ([`scripts/inspect-pcf-project.ps1`](../scripts/inspect-pcf-project.ps1)
  reports it), propose a change if needed, and show the edit — never flip
  it silently.
- Solution **unique name, display name, and major/minor version** live in
  `src/Other/Solution.xml`. `pac solution init` cannot set the name (no
  such flag exists); `pac solution version` cannot set major/minor (build
  and revision only — see [Versioning](#versioning)).
- **Discover the artifact path** by enumerating `bin\**\*.zip` (both
  `Debug` and `Release`) after the build, and report what was actually
  produced with size and timestamp. Never assume
  `bin\Debug\<ProjectName>.zip`.
- **Never rename a generated `.zip` and never edit its contents.** If
  packaging output is wrong, fix the source project and rebuild.
- Keep four names distinct and record all four in the spec §15: solution
  **display name**, solution **unique name**, solution **project/directory
  name**, and the produced **zip filename**. They are not interchangeable.
- Ensure the solution project name and the PCF project name are not
  identical — [`scripts/inspect-pcf-project.ps1`](../scripts/inspect-pcf-project.ps1)
  warns on this collision.

## Versioning

| Artifact | Mechanism |
|---|---|
| Control version | `ControlManifest.Input.xml` `version` attribute, or `pac pcf version` (`--strategy None\|GitTags\|FileTracking\|Manifest`, `--patchversion`, `--allmanifests`, `--updatetarget build\|project`) |
| Solution build/revision | `pac solution version --buildversion / --revisionversion / --strategy` |
| Solution major/minor | Edit `src/Other/Solution.xml` directly — **not** available via `pac solution version` |

A version bump invalidates Gate C. See
[Post-deployment verification](#post-deployment-verification) for why a
missed control-version bump is the most common cause of a "my change didn't
apply" report.

### Control version policy (this skill's default)

PCF control manifest versions are conventionally three-segment
`MAJOR.MINOR.BUILD` (e.g. `1.0.0`) — confirm the actual format in the
scaffolded `ControlManifest.Input.xml` before applying this logic; do not
assume a fourth segment exists. This policy only ever touches the
**third (BUILD) segment** — not MAJOR, not MIDDLE — to avoid the
MAJOR.MINOR.PATCH naming ambiguity: "MINOR" in strict semver terms names
the *middle* segment, but the increment this policy applies is to the
*last* one, so the mechanics below are described positionally rather than
by name.

- **New project:** `pac pcf init` generates the manifest with
  `version="0.0.1"`. Immediately after scaffold (S3), set it to
  **`1.0.0`** and show the diff. See
  [workflow.md § S3](workflow.md#s3--scaffold-or-existing-project-assessment).
- **Existing project encountered for the first time under this policy:**
  S3 Branch B does **not** retroactively rewrite anything by default — it's
  read-only assessment. If the manifest version isn't already `1.0.0` and
  spec §19 shows no deployment history (never deployed), **propose** a
  one-time reset to `1.0.0` as an approvable question, with the reasoning
  above. If the project has already been deployed at least once, leave the
  version alone — a retroactive change to a version already live in an
  environment risks a [T26](troubleshooting.md#t26--version-conflict-on-import)-style
  conflict on the next import, so the per-publish bump below just continues
  from whatever the current version is.
- **Every publish after the first:** before Gate C, propose incrementing
  the **third segment** by one, leaving the first two unchanged — e.g.
  `1.0.0` → `1.0.1` → `1.0.2`. The very first publish ships the initial
  `1.0.0` unchanged; the bump starts applying from the second deployment
  onward, so an environment that has never seen this control gets exactly
  `1.0.0`.
- **Preferred mechanism:** `pac pcf version` targets exactly this segment
  (its `--patchversion` / `--strategy None|GitTags|FileTracking|Manifest`
  arguments) — but its **auto-increment semantics are unverified** here
  (whether a given `--strategy` bumps by one automatically, or requires an
  explicit `--patchversion <value>`). Run `pac pcf version help` on the
  actual machine to confirm current behavior before relying on it. If it
  doesn't do what's needed, fall back to a **direct edit** of the `version`
  attribute in `ControlManifest.Input.xml` — always correct, no
  CLI-version dependency.
- **The first two segments never change** under this default policy —
  only on an explicit user request (e.g. a feature-level or breaking-change
  release).
- **Always show the current version, the proposed version, and this
  reasoning as a row in Worksheet W7.** The user can approve it or
  override it (a different bump, or none) like any other worksheet row —
  never apply it silently.
- This is the skill's built-in default, not something asked about like
  publisher or environment. If the user states a different control-version
  policy, record it in spec §16 and follow that instead.

## Environment selection (Worksheet W8)

Asked first, before Worksheet W7 — the classification captured here decides
which W7 shape follows, and whether S11 (Gate C) runs at all. See
[Development deployments run without a confirmation gate](#development-deployments-run-without-a-confirmation-gate)
for the full `development` rule, which now covers the first deployment to
a new dev environment too, not just repeats.

**Case 1 — `test`/`UAT`/`staging`/`production`, any time: asked every
time, no exceptions, full Gate C follows.**

Before **any** remote operation:

1. Ask for the **exact** target environment URL or ID. Never infer it from
   a previous session, a spec entry, or "the usual one" — always confirm.
2. Ask for the **classification**: development / test / UAT / staging /
   production. Classification drives confirmation strength (see Gate C) and
   the deployment method suggested in Worksheet W7, below.
3. Propose `pac auth list` and read the result.
4. **Reuse** an existing correct profile when one matches the target.
5. `pac auth select --name <profile>` or `--index <n>` when switching.
6. Create a profile **only** when none matches:
   `pac auth create --name "<profile-name>" --environment "<target>"` —
   interactive sign-in, or `--deviceCode` when a browser is unavailable.
7. Run `pac auth who`.
8. Show: selected profile name, signed-in user, tenant information when
   available, and the exact environment the profile resolves to.
9. **Compare** the authenticated environment against the requested target.
10. **Stop** if they do not match. Do not "fix" it by re-creating a
    profile — select or correct, then re-verify.

**Case 2 — a `development` target never before used for this project:**
steps 1-2 above still have to happen once — the tool genuinely does not
know the URL or classification yet, and this is information-gathering,
not a confirmation to deploy. Steps 3-10 (auth discovery/verification)
also run, but **without pausing for a reply** unless step 9's comparison
actually fails or step 6 needs a brand-new profile (in which case
`pac auth create` runs its normal interactive/`--deviceCode` sign-in,
which inherently requires the user's participation — that's
authentication, not a confirmation gate). Once classification comes back
`development`, **no Gate C follows** — not even on this first deployment.
See [Development deployments run without a confirmation gate](#development-deployments-run-without-a-confirmation-gate).

**Case 3 — a `development` target already on record for this project**
(recorded in spec §17, from any prior S10 pass — this session or an
earlier one): steps 1-2 are not re-asked at all — the recorded URL and
classification are reused automatically. Steps 3-10 run silently, exactly
as in Case 2, surfacing only on an actual mismatch.

Rules:
- Never accumulate duplicate profiles. If `pac auth list` already shows a
  profile for the target, use it.
- **Never** pass `--password`, `--clientSecret`, or `--certificatePassword`
  as a CLI argument — these are plain-text arguments on this CLI and would
  land in shell history and the session transcript. Service-principal
  authentication is the user's responsibility to run outside the skill.
- Never echo, log, or write tokens or any content from the PAC auth store.
  Redact anything token-like in captured `pac auth who` output before
  showing it.
- Classification is **user-asserted**, never verified against the
  environment itself (Dataverse exposes no "this is a dev sandbox" flag).
  If a target is ever misclassified as `development`, this policy deploys
  to it without asking — from the very first deployment onward — until
  the user corrects the classification on record. This is the direct,
  stated consequence of removing the confirmation gate for `development`
  entirely — see
  [Development deployments run without a confirmation gate](#development-deployments-run-without-a-confirmation-gate).
- **Read-only `pac` commands never require confirmation, for any
  classification.** `pac auth list`, `pac auth who`, `pac solution list`,
  `pac solution check` cannot write to an environment, so nothing in this
  file gates them — they run and their output is reported. Only commands
  that push, import, publish, upgrade, or delete are ever gated.

## Worksheet W7 — packaging decisions

### Deployment method comes first

**For test/UAT/staging/production, this question is asked every single
time S10 is reached — first deployment or the tenth redeploy, no
exceptions.** Recording the chosen method in spec §16 (below) makes it
available as the *suggested default* next time, not a decision that's now
permanent. Do not treat "already recorded in the spec" as a reason to skip
asking — see the explicit carve-out in
[SKILL.md rule 8](../SKILL.md#non-negotiable-rules) and
[workflow.md § Worksheet protocol](workflow.md#worksheet-protocol). A prior
choice of `package` does not mean every subsequent redeploy uses `package`
without being asked again — classification could have changed, the target
environment could have changed, or the user might simply want push this
time.

**For a `development` target already established for this project**, the
method is reused automatically from spec §16 without being re-asked —
see
[Development deployments run without a confirmation gate](#development-deployments-run-without-a-confirmation-gate)
for the full scope of what this does and does not skip.

W7's shape depends on the environment classification just captured in
[Worksheet W8](#environment-selection-worksheet-w8):

| Classification | Suggested method | Basis |
|---|---|---|
| `development` | [`pac pcf push`](#development-push) | Fast dev inner-loop; always unmanaged; no persistent solution project to maintain |
| `test` / `UAT` / `staging` / `production` | [Solution package + `pac solution import`](#solution-packaging-flow) | Versioned, source-controlled artifact; managed/unmanaged choice; the ALM-tracked path |

This is a **suggestion shown as a worksheet row, not a silent branch** — the
user can override it either direction: a development target may explicitly
want the full package method (e.g. building toward a managed artifact for
later promotion); a non-development target insisting on push gets the
stronger warning already required in [Development push](#development-push).
Record whichever method is chosen in spec §16. For a full worked
walkthrough of a development target explicitly overriding to the package
method, see
[examples/package-method-dev-example.md](../examples/package-method-dev-example.md).

### Naming the method directly

If the user directly names a specific method or command — "push", "pac pcf
push", "import the solution", "solution import" — treat that as answering
the method-selection row only. It narrows *which* Worksheet W7 shape
applies; it does not skip anything else that's still genuinely unknown:
environment/classification/auth (Worksheet W8) still need establishing if
not already on record for this project, and the remaining W7 rows
(publisher prefix, or the full package fields) are still asked if
unknown. For `test`/`UAT`/`staging`/`production`, the control-version
bump proposal and Gate C's readiness report and typed confirmation still
run in full regardless. For **any** `development` target — first
deployment or the hundredth — none of that follows; see
[Development deployments run without a confirmation gate](#development-deployments-run-without-a-confirmation-gate).

Naming `push` specifically also does **not** override the dev-only guard:
if the confirmed environment classification turns out to be
test/UAT/staging/production, the warning and the stronger
`CONFIRM PRODUCTION IMPORT ...` confirmation in
[Development push](#development-push) still apply — a user naming the tool
is not the same as a user acknowledging the production risk.

### Development deployments run without a confirmation gate

A control being iterated in a dev inner loop can hit S10 many times in one
sitting, or across many sessions — fix a bug, push, fix another, push
again. For **any** `development`-classified target — including the very
first deployment to a brand-new dev environment — this runs with **no
Gate C**: no readiness report, no typed confirmation string, not even a
short one. `test`/`UAT`/`staging`/`production` are entirely unaffected by
anything in this section; they always get the full W8/W7 tables and the
full typed `CONFIRM PRODUCTION IMPORT ...` string at Gate C, every time,
forever.

**What still has to be asked once, and why it isn't a confirmation
gate:** the very first time a given environment is used for a project,
the tool genuinely does not know its URL, or (if the method is push) its
publisher prefix, or (if the method is package) the full W7 package
fields. These are asked — see
[Worksheet W8 Case 2](#environment-selection-worksheet-w8) — because a
wrong guess would be actively harmful, not because the deployment needs
approval. This is information-gathering, indistinguishable in kind from
Worksheet W1 asking what the control should do. It happens once per
environment, not once per push, and the moment classification comes back
`development`, whatever S10 flow led to that point (first-time or
established) proceeds straight through S11 with no gate.

**What runs automatically, with no prompt, on every push to a
`development` target, first or subsequent:**
- `pac auth list` / `pac auth who` verification that the resolved
  environment matches the target (see
  [Worksheet W8](#environment-selection-worksheet-w8)) — runs every time,
  silently, surfacing as a question only if it actually finds a mismatch
  or would need to create a brand-new auth profile (which itself requires
  interactive/`--deviceCode` sign-in — authentication, not a confirmation
  gate). That is an anomaly check, not a confirmation.
- The control-version bump, applied per the
  [control version policy](#control-version-policy-this-skills-default)
  — computed and applied, not proposed for approval. On a genuine first
  deployment this is `1.0.0` unchanged, per that policy; from the second
  deployment onward it's the usual `+1` to the third segment.
- Read-only diagnostics used along the way (`pac solution list`,
  `pac solution check`) — never gated, for any classification; see
  [Worksheet W8's closing rule](#environment-selection-worksheet-w8).
- The push (or import, if this dev target explicitly uses the package
  method) itself.

**What is never skipped, regardless of classification:**
- Gate A and Gate B — these gate the *design* and the *manifest*, not the
  deployment, and are untouched by anything in this section. They exist
  to confirm the work matches the actual requirement; nothing about
  removing deployment friction touches that.
- `pac solution publish` (publish-all-customizations) — always its own,
  separately confirmed operation with its own readiness report and typed
  string, for **any** classification including `development`, because it
  affects every customization in the environment, not just this control.
  Nothing in this section authorizes it.
- Transparency: immediately before running, show a brief one-line
  heads-up (operation, environment, version) — not a question, just
  narration of what's about to happen — and immediately after, the full
  [Post-deployment verification](#post-deployment-verification) report
  runs exactly as it would for any other deployment. The absence of a
  blocking gate is not an absence of information; the user always sees
  what happened, just after rather than being asked before.

**Reverting a specific target to full confirmation:** the user can say so
explicitly at any time (e.g. "always confirm before pushing to this
environment") — record it in spec §16 as a per-environment override, and
from then on that target's S10 runs the full W8/W7/Gate C flow like any
test/UAT/staging/production target, regardless of its classification.

**The residual risk, stated plainly:** classification is user-asserted
and unverifiable by the tool (see
[Worksheet W8](#environment-selection-worksheet-w8)). This policy trades
the confirmation gate — on every deployment, including the first — for
speed, on the explicit understanding that `development` targets are
low-stakes; if a target is ever misclassified, there is no remaining
checkpoint before code reaches it.

See [package-method-dev-example.md](../examples/package-method-dev-example.md#s11-no-gate-c-for-development)
and [field-control-example.md § S13](../examples/field-control-example.md#s13-verification)
for worked transcripts, and contrast with a `test`/`UAT`/`staging`/`production`
redeploy, which always runs the full tables and Gate C.

### W7 — push method

Ask together (publisher prefix is always asked blank — a wrong guess is not
harmless):

Publisher prefix · **the proposed control-version bump** (current →
proposed, per the [control version policy](#control-version-policy-this-skills-default)).

Push runs as `pac pcf push --environment "<url>" --publisher-prefix
"<prefix>"` — nothing else.

No display name, solution version, build-path, Checker, or managed/unmanaged
questions either — `pac pcf push` doesn't use a persistent solution project,
and it is unconditionally unmanaged (state this to the user rather than
asking it).

### W7 — package method

Ask together, with suggested values where a wrong guess is not harmful
(publisher prefix and environment values are always asked blank):

Publisher display/name · publisher prefix · solution unique name · solution
display name · solution version · **managed or unmanaged** · PCF project
path · solution project path · output artifact path · whether Power Apps
Checker runs · whether customizations are published after import · **the
proposed control-version bump** (current → proposed, per the policy above).

Rules:
- Validate the publisher prefix against `pac solution init help` and,
  once an environment is reachable, against the publisher that already
  exists there. A prefix mismatch at push/import time is
  [troubleshooting.md T21](troubleshooting.md#t21--wrong-publisher-prefix),
  not a naming preference to guess around.
- **Managed vs. unmanaged is always an explicit question, every time —
  never silently defaulted or inferred from environment classification.**
  A suggested value may be shown (e.g. managed for downstream environments)
  with its basis stated, but it is still a worksheet row requiring the
  normal approve/edit response — not a precondition that's assumed and
  skipped. If the user's spec §15 already records a stated ALM policy, show
  it as the suggested value and its basis, and still ask.

### Both methods

The control-version bump row follows the same rule in either worksheet
shape: shown with its computed value and reasoning, approved or overridden
explicitly, never applied without being on the worksheet.

## Development push

This is the **suggested default method for development-classified targets**
— see [Worksheet W7 § Deployment method comes first](#deployment-method-comes-first).
For any `development` target — including the first time it's used — this
command runs without a confirmation gate — see
[Development deployments run without a confirmation gate](#development-deployments-run-without-a-confirmation-gate)
for exactly what that does and does not skip.

Verified argument set — note there is **no** `--path`, so push acts on the
**current directory**:

```powershell
Set-Location "<pcf-project-root>"
pac pcf push --environment "<target-environment>" --publisher-prefix "<prefix>"
```

- Re-verify every flag against `pac pcf push help` before proposing the
  command — this is a snapshot, not a contract.
- Push builds a temporary solution wrapper via MSBuild (its own
  `--verbosity` help text says so), so it needs the .NET SDK or MSBuild in
  addition to Node — confirm both are available before proposing push.
- **Development inner-loop tool only.** Never the default production
  deployment method. If asked to push to a UAT/production-classified
  environment, explain why that is inappropriate, offer the solution-import
  path instead, and require the strong confirmation (below) if the user
  insists.
- `--force-import` is deprecated — do not propose it.
- `--incremental` changes update semantics — propose only on request, and
  explain what it does.

## Solution import

```powershell
pac solution import --path "<discovered-artifact-path>" --environment "<target-environment>"
```

- `--publish-changes` **only** on explicit approval, shown as its own line
  in the readiness report.
- Never automatically add: `--force-overwrite`, `--skip-dependency-check`,
  `--import-as-holding`, `--stage-and-upgrade`, `--activate-plugins`,
  `--convert-to-managed`, `--skip-lower-version`. Each is a separate
  decision with its own explanation and its own line in the readiness
  report.
- `pac solution upgrade` and `pac solution delete` are **separate verbs**,
  not import flags — treat them as separate high-impact operations with
  their own confirmation if ever requested.
- Prefer the default **synchronous** import. If `--async` is used, state
  clearly that a successful exit proves *submission*, not *completion* —
  the default `--max-async-wait-time` is 60 minutes, meaning the default
  behavior already waits.

## Publish all customizations

`pac solution publish`'s complete verified argument list is
`--environment`, `--async`, `--max-async-wait-time` — **no scoping
arguments of any kind.** It publishes every customization in the selected
environment.

- Never run it as a follow-on to an import.
- Never present it as scoped to one solution or component — it is not.
- If requested, it gets its **own** readiness report and its own typed
  confirmation naming the environment, exactly like any other remote
  write — for **any** classification, including `development`. The
  [development no-confirmation policy](#development-deployments-run-without-a-confirmation-gate)
  covers pushing/importing *this control only*; it never extends to an
  environment-wide operation like publish-all.

## Gate C — deployment readiness report

**Applies to `test`/`UAT`/`staging`/`production`, always.** It does
**not** apply to `development`, at all, including the first deployment to
a brand-new dev environment — see
[Development deployments run without a confirmation gate](#development-deployments-run-without-a-confirmation-gate)
for what replaces it there (a non-blocking heads-up line before, and the
full [Post-deployment verification](#post-deployment-verification) report
after).

Before any in-scope remote command that pushes, imports, publishes,
upgrades, or deletes, present the report using
[`templates/deployment-readiness.md`](../templates/deployment-readiness.md):

| Field | Source |
|---|---|
| Gate A — React design approval | Spec §18 (`approved` / `overridden` / `pending`) |
| Gate B — Manifest approval | Spec §18 (`approved` / `pending`) |
| Deployment method | Worksheet W7's method row — push or package, and why |
| Operation | The exact command that will run |
| Environment classification | User-supplied (W8) |
| Exact environment URL/ID | User-supplied (W8) |
| Authenticated user / profile | `pac auth who` |
| Control name and version | `ControlManifest.Input.xml` |
| Solution unique name and version | `Solution.xml` — for a no-name push (see [W7 § push method](#w7--push-method)), state "not explicitly named; `pac pcf push` default solution" instead, and report the actual solution name once observed via `pac solution list` at S13 |
| Publisher name and prefix | Solution project |
| Package type | Managed / Unmanaged, from `SolutionPackageType` + the actual artifact |
| Exact artifact path | **Discovered** from the build output, with size and timestamp |
| Build result | The build command's outcome |
| Checker result | If `pac solution check` was run; otherwise "not run" |
| Publish changes requested? | Yes/No, explicitly |
| Expected impact | What will change in the environment |
| Rollback / recovery | How to revert, and whether reverting is possible at all |

Then require a **typed** confirmation — never "yes," "ok," "go," or
similar. Both strings use `<target-identifier>`: the **solution unique
name** for the package method, or the **control name** for push, since
push never carries a chosen solution identity:

- Test:
  ```
  DEPLOY <target-identifier> TO <environment-url>
  ```
- UAT / staging / production:
  ```
  CONFIRM PRODUCTION IMPORT <target-identifier> <version> TO <environment-url>
  ```

`development` never reaches this point — see the scope note above.

Single-use. Any change to files, versions, build output, auth profile,
environment, publisher, package type, or artifact **invalidates** it — see
the full [gate invalidation matrix](workflow.md#gate-invalidation-matrix).
Regenerate the report and ask again. Echo the confirmed command verbatim
immediately before running it. Deployment vocabulary in a request is never
itself authorization for `test`/`UAT`/`staging`/`production` — see
[SKILL.md](../SKILL.md).

## Post-deployment verification

Runs after **every** deployment, regardless of classification or which
Gate C path applied — including a `development` deployment that skipped
the confirmation gate entirely. For that case, this report is the
primary place the user actually sees what happened, so don't compress it:
state the operation, environment, and version that were actually used,
not just "push succeeded."

1. **Confirm the command actually succeeded** — exit code plus the CLI's
   own success text. If `--async` was used, an exit code proves submission
   only; wait for the real result before reporting success.
2. **Record the imported solution version** as reported by the
   environment, not as intended locally.
3. **Confirm the expected solution/control exists** — `pac solution list`
   against the target environment (a read-only remote operation; runs and
   reports without needing confirmation, like any read-only `pac`
   command).
4. **Re-confirm the target environment** with `pac auth who` after the
   operation.
5. **Report warnings and dependency issues** from the import output
   verbatim, including ones that did not fail the import.
6. **Explain required manual maker-portal steps** — e.g. adding the control
   to a form or view, configuring properties on the form control,
   publishing the form, enabling the control for a specific app.
   `pac solution import` does not place a control on a form.
7. **Provide a focused smoke-test checklist** derived from the Gate A
   approved states: normal render, empty, loading, error, disabled,
   read-only, keyboard navigation, and the specific user actions from the
   requirement.
8. **Avoid unrelated environment changes.** No publishing all
   customizations, no touching other solutions, no cleanup of unrelated
   components.
9. **Update the spec §19** — append a deployment-history row: date,
   operation, environment, solution version, control version, outcome,
   verification result.

State what was verified and what was not. "Import reported success and
`pac solution list` shows version 1.0.0.3 in `<env>`; I have not opened the
app, so runtime behavior in the form is unverified — here is the smoke-test
checklist" is the correct shape. A zero exit code alone does not mean the
control works in the app.

If a user reports "my change didn't appear," the first hypothesis is a
control version that was not bumped, plus host/browser caching — not a
code defect. Check `ControlManifest.Input.xml` `version` against what is
deployed before debugging the component.

## Git and filesystem safety

Applies at every stage, not only deployment:

- `git status --short` before the first edit of a session; show anything
  already modified.
- Preserve unrelated user changes. Never overwrite a file that has not
  been read.
- Show the planned file list before any refactor touching more than a
  couple of files.
- **Never** `git commit`, `push`, `reset`, `clean`, `checkout <branch>`,
  `stash`, or `rebase` unless the user explicitly asks.
- Ensure `.gitignore` covers `node_modules/`, `out/`, `bin/`, `obj/`,
  `preview/node_modules/`, `preview/dist/`, and generated bundle output —
  propose the additions, show the diff, never silently rewrite the file.
- Never write a secret to the repository, including in the spec (see the
  banner in [`templates/control-spec.md`](../templates/control-spec.md)).
- Preview scaffolding with ongoing value is kept; temporary scaffolding is
  removed only after asking.
- If the directory is not a git repository, say so once and note there is
  no undo safety net for the edits about to be made.

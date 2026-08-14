# Workflow: the 13-stage state machine

## Table of contents
- [Overview and movement rules](#overview-and-movement-rules)
- [S1 — Requirement discovery](#s1--requirement-discovery)
- [S2 — Prerequisite and repository inspection](#s2--prerequisite-and-repository-inspection)
- [S3 — Scaffold or existing-project assessment](#s3--scaffold-or-existing-project-assessment)
- [S4 — Standalone React design and preview](#s4--standalone-react-design-and-preview)
- [S5 — GATE A: React design approval](#s5--gate-a-react-design-approval)
- [S6 — Manifest design proposal](#s6--manifest-design-proposal)
- [S7 — GATE B: Manifest approval](#s7--gate-b-manifest-approval)
- [S8 — PCF integration](#s8--pcf-integration)
- [S9 — Local validation and test](#s9--local-validation-and-test)
- [S10 — Deployment preparation](#s10--deployment-preparation)
- [S11 — GATE C: Deployment confirmation](#s11--gate-c-deployment-confirmation)
- [S12 — Remote operation](#s12--remote-operation)
- [S13 — Post-deployment verification](#s13--post-deployment-verification)
- [Gate invalidation matrix](#gate-invalidation-matrix)
  - [Gate A/B: one-time approval, not per-change](#gate-ab-one-time-approval-not-per-change)
  - [Labeling a change: defect correction vs. design change](#labeling-a-change-defect-correction-vs-design-change)
- [Worksheet protocol](#worksheet-protocol)
- [Existing-project change map](#existing-project-change-map)
- [Resume protocol](#resume-protocol)

## Overview and movement rules

```
S1  Requirement discovery
S2  Prerequisite + repository inspection
S3  Scaffold / existing-project assessment
S4  Standalone React design + preview
S5  ══ GATE A: React design approval ══
S6  Manifest design proposal
S7  ══ GATE B: Manifest approval ══
S8  PCF integration
S9  Local validation + test
S10 Deployment preparation
S11 ══ GATE C: Deployment confirmation (typed) ══
S12 Remote operation
S13 Post-deployment verification
```

- Forward movement requires the previous stage's completion criteria (below) to be met and recorded in `docs/pcf/<control-name>-spec.md`.
- "back" / "go back to <stage>" returns to that stage and **invalidates every downstream gate approval**.
- Gate A and Gate B, once approved for a control, persist permanently — across sessions and across every later code/CSS/manifest change, with one exception (converting a standard control to React; see the matrix below). Gate C is single-use and never survives a session boundary.
- A request that names a later stage does not skip earlier ones. "Just deploy it" enters at S10 and the response opens with which earlier stages are unsatisfied — see [approval-gates-example.md](../examples/approval-gates-example.md).

---

## S1 — Requirement discovery

- **Required inputs:** the business requirement in the user's words; new vs. existing project.
- **Inferable from project:** presence of `*.pcfproj`, `ControlManifest.Input.xml`, `*.cdsproj`, `package.json`, `docs/pcf/*-spec.md`. A prior spec means resume, not restart — go to [Resume protocol](#resume-protocol).
- **Must ask — Worksheet W1** (batched, one message): control purpose; target host (model-driven app / canvas app / custom page / other); field vs dataset; React vs standard; main user actions; inputs; outputs; bound column if any.
- **Files created/modified:** none. The spec file is created at S3, once inspection confirms the project shape it describes.
- **Commands:** none beyond read-only file globbing.
- **Completion criteria:** purpose, host, template, and framework are known and echoed back.
- **Must not before approval:** scaffold anything; install anything; write code.

## S2 — Prerequisite and repository inspection

- **Required inputs:** none.
- **Must ask:** nothing, unless a BLOCK is found — then, how the user wants to proceed.
- **Files:** none written.
- **Commands (read-only — run directly and report the result; these are inspection, not mutation, so they don't need a chat-level proposal on top of whatever the permission system already requires):** `node --version`, `npm --version`, `pac --version`, locate `pac` with `Get-Command pac`, `dotnet --version`, `dotnet --list-sdks`, `Get-Command msbuild` then `vswhere` discovery, `git --version`, `git status --short`, `git rev-parse --is-inside-work-tree`, `pac pcf init help`, a scan of `~/.vscode/extensions` for `*powerplatform*`/`*IsvExpTools*`. Or run [`scripts/check-prerequisites.ps1`](../scripts/check-prerequisites.ps1), which does all of this in one pass. (Windows/PowerShell only — the script relies on `Get-Command`, `vswhere.exe`, and Windows environment variables; on macOS/Linux, run the individual commands listed above instead.)
- **Completion criteria:** a prerequisite table (tool / status / version / path / verdict) is shown; every BLOCK is resolved or explicitly accepted and recorded as a limitation.
- **Must not:** install anything; run `pac install latest`; modify PATH; proceed to S3 with an unacknowledged BLOCK.

## S3 — Scaffold or existing-project assessment

**Branch A — new project**
- **Must ask — Worksheet W2:** project root; control name; namespace; output directory; run npm install now?; publisher prefix *if already known* (otherwise deferred to S10).
- **Validate before running anything:** propose control name/namespace values and state the rule applied; if `pac` rejects a value, its error text — not a re-guess — drives the correction.
- **Commands:** `pac pcf init` with explicit `--namespace`, `--name`, `--template`, `--framework`, `--outputDirectory`, `--run-npm-install`, in the active shell's syntax — see [field-control-example.md § S3](../examples/field-control-example.md#s3-scaffold-new-project) for the full command line.
- **Files created:** the generated scaffold (by `pac`, not by the skill) + `docs/pcf/<control-name>-spec.md` from [`templates/control-spec.md`](../templates/control-spec.md).
- **Post-scaffold version initialization:** `pac pcf init` generates `ControlManifest.Input.xml` with `version="0.0.1"`. Immediately edit it to `version="1.0.0"` — this skill's fixed starting convention — and show the one-line diff to the user. This is a version-scheme initialization, not a business-specific manifest change, so it does not require the Gate B package; it does need to be recorded in the spec §16 control-version policy. See [deployment-and-alm.md § Versioning](deployment-and-alm.md#versioning) for the full policy, including how this interacts with the per-publish minor bump.
- **Completion criteria:** scaffold exists; `package.json`, `ControlManifest.Input.xml`, `tsconfig.json`, `index.ts` have been **read**; the manifest version has been set to `1.0.0`; discovered versions and script names recorded in the spec.

**Branch B — existing project**
- **Commands:** read-only; optionally [`scripts/inspect-pcf-project.ps1`](../scripts/inspect-pcf-project.ps1).
- **Must determine and record:** control type (standard vs virtual) from the manifest — never from what the user assumed; existing properties/datasets/features/resources; `package.json` script inventory; ESLint config style (legacy / flat / pcf-scripts-provided / none); `tsconfig.json` inheritance; lockfile presence; existing solution project(s); existing spec file.
- **Version-convention check (proposed, not applied):** if the manifest version is not already `1.0.0` and spec §19 deployment history is empty or no spec exists yet (i.e. this project has never been deployed), propose a one-time reset to `1.0.0` to adopt this skill's starting convention, and explain why. If the project has already been deployed at least once, leave the version untouched — the per-publish bump policy continues from whatever it currently is. See [deployment-and-alm.md § Control version policy](deployment-and-alm.md#control-version-policy-this-skills-default).
- **Completion criteria:** an assessment summary is shown, including an explicit statement when the project *is* something different from what the user *said* it is.
- **Must not:** "modernize" the scaffold; replace `package.json`; change `control-type`; run `npm install` before showing what would change.

## S4 — Standalone React design and preview

Full detail: [react-preview-and-architecture.md](react-preview-and-architecture.md).

- **Must ask — Worksheet W3:** states to cover; responsive behavior; accessibility requirements; localization languages; Fluent UI usage; design-system/CSS conventions; mock-data shape.
- **Files created:** the real component + scoped CSS, in its final PCF location, plus an isolated preview harness.
- **Commands:** the preview install/build/dev-server commands; screenshot capture if a browser/screenshot tool is available in the session. **Every one of them has its exit status and output checked** — a command is not "run", it is run *and read*.
- **On any failure — a non-zero exit, an error in the output, a console error, a blank or error-overlay page:** report it to the user immediately with the exact first error text, apply one targeted fix, re-run the same command and the same check, and ask the user to reload and confirm. Repeat until they confirm. Full protocol: [react-preview-and-architecture.md § Preview verification loop](react-preview-and-architecture.md#preview-verification-loop-before-gate-a); blank-page diagnosis: [troubleshooting.md § T28](troubleshooting.md#t28--preview-renders-blank--no-elements-on-the-page).
- **Completion criteria:** the preview has been checked to render (commands exited clean, mount root non-empty, no console/overlay error) **and** the user has explicitly confirmed they can see it rendering correctly for every relevant state, and knows exactly which data is mocked. An unverified or unconfirmed preview does not complete this stage.
- **Records:** the spec §5 preview-verification log — one row per failed round: signal, cause, fix, re-check result.
- **Must not:** present a preview as ready without checking it; retry a failing command silently and show only the run that worked; substitute a static mock or a description of the intended UI for a preview that failed to render; write manifest business properties; add `feature-usage`; call `context.webAPI`; wire outputs; touch deployment configuration.

## S5 — GATE A: React design approval

**Applies once per control — the first time it's ever built.** For a
control that has already had Gate A approved at any point in the past
(any session), later updates do not come back through this gate at all —
see [Gate A/B: one-time approval, not per-change](#gate-ab-one-time-approval-not-per-change).
Everything below describes the first-build case.

**Precondition — the S4 render confirmation.** This gate is not asked
while the preview is unverified or unconfirmed. If the user approves the
design anyway (from the source, or before the page ever rendered), that is
not a valid Gate A approval: say the preview hasn't been confirmed to
render yet, run the render check, and ask this question afterward. The two
questions stay separate and in order — *can you see it* first, *do you
approve it* second. See
[react-preview-and-architecture.md § Preview verification loop](react-preview-and-architecture.md#preview-verification-loop-before-gate-a).

Ask verbatim:

> "Do you approve this React design for manifest design and PCF integration, or should I change the UI or behavior first?"

- **Accepted:** an explicit affirmative directed at this exact question.
- **Not accepted:** "looks okay", "nice", silence, or approval of something else in the same message. Re-ask, naming the ambiguity.
- **Change path:** modify → refresh preview → **re-run the verification loop (checks + user confirmation)** → re-capture screenshots → re-run checks → re-ask. Unlimited iterations, each logged in the spec §5 iteration log. A change that breaks the preview is reported and fixed before the gate question comes back.
- **Override:** only on an explicit instruction of the form "Skip the React preview approval gate." Record it in the spec verbatim with a timestamp. Manifest approval (Gate B) and deployment confirmation (Gate C) are still required after an override.
- **Records:** gate status, iteration count, screenshot paths — spec §18 and §5.

## S6 — Manifest design proposal

Full detail: [manifest-design.md](manifest-design.md).

- **Required inputs:** Gate A status (approved or explicitly overridden); target host; template.
- **Inferable:** current `ControlManifest.Input.xml`; existing RESX keys; existing resource paths; generated `platform-library` entries.
- **Must produce:** control metadata proposal; property table; dataset/property-set configuration if applicable; type groups if justified; feature usage; external-service usage; resources table; React-prop ↔ `context.parameters` ↔ `getOutputs` mapping.
- **Files:** none written yet.
- **Must not:** edit the manifest; run `refreshTypes`.

## S7 — GATE B: Manifest approval

**Applies once per control — the first time its manifest is built.** For
a control that has already had Gate B approved at any point in the past,
later manifest changes do not come back through this gate — see
[Gate A/B: one-time approval, not per-change](#gate-ab-one-time-approval-not-per-change).
Everything below describes the first-build case.

Show all eleven items from [manifest-design.md § Gate B package](manifest-design.md#gate-b-package), then ask verbatim:

> "Do you approve this manifest proposal for PCF integration?"

- Row-level edits supported: `edit P2: of-type=SingleLine.Email` → re-present affected rows + regenerated XML → re-ask.
- Only explicit approval continues. Record the approved proposal verbatim in the spec §9–§14.

## S8 — PCF integration

- **Required inputs:** Gate B approval.
- **Files modified:** `ControlManifest.Input.xml`; `index.ts`; the React component (props widened to the approved contract); RESX files; CSS path if changed.
- **Commands:** `npm run refreshTypes` — only if that script exists in `package.json`.
- **Completion criteria:** generated `ManifestTypes.d.ts` contains every approved property; the component compiles against it; no manual edits to generated typings.
- **Must not:** call `notifyOutputChanged` during render; issue WebAPI calls during render; pass raw `context` into components without a documented reason; hand-edit `ManifestTypes.d.ts`.

## S9 — Local validation and test

Full detail: [build-and-testing.md](build-and-testing.md). Order: type generation → type check → lint (if configured) → dev build → production build → PCF test harness (`npm start`) → unit tests (if present) → manifest/resource consistency ([`scripts/validate-pcf-project.ps1`](../scripts/validate-pcf-project.ps1)). Each step runs only if its script/config exists. Failures route to [troubleshooting.md](troubleshooting.md).

## S10 — Deployment preparation

Full detail: [deployment-and-alm.md](deployment-and-alm.md). **This stage
has two distinct shapes** — read which one applies before following the
bullets below:

- **Classification is `test`/`UAT`/`staging`/`production`:** everything
  below runs as written — ask, propose, confirm — every single time,
  first deployment or the hundredth.
- **Classification is (or turns out to be) `development`:** the
  genuinely-unknown values below (environment URL if new, publisher
  prefix if new, method if not yet decided) are still asked **once per
  environment**, because a wrong guess would be harmful — this is
  information-gathering, not a confirmation to deploy. Everything else
  (the version-bump proposal becoming an approval step, and Gate C
  itself) does **not** apply, from the first deployment onward. See
  [deployment-and-alm.md § Development deployments run without a
  confirmation gate](deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate)
  for the complete rule, including the one operation this never covers
  (`pac solution publish`, always separately confirmed regardless of
  classification).

**For `test`/`UAT`/`staging`/`production`:**

- **Must ask — Worksheet W8 first:** environment URL/ID, environment classification, auth profile choice. Classification decides which deployment method comes next, so W8 is resolved before the rest of W7.
- **Propose a deployment method (a worksheet row, not a silent branch):**
  - Classification `development` → suggest `pac pcf push` (the dev inner-loop path): fast, always unmanaged, no persistent solution project.
  - Classification `test`/`UAT`/`staging`/`production` → suggest the full solution-package + `pac solution import` path.
  - Either suggestion can be overridden — a dev target may explicitly want the full package (e.g. building toward a managed artifact for promotion); a non-dev target insisting on push gets the stronger warning already required in [deployment-and-alm.md § Development push](deployment-and-alm.md#development-push).
  - If the user names a method directly (e.g. "push", "import the solution") instead of waiting for the suggestion, that only answers this one row — it does not skip W8, the rest of W7, the version-bump proposal, or Gate C, and it does not override the dev-only guard on push. See [deployment-and-alm.md § Naming the method directly](deployment-and-alm.md#naming-the-method-directly).
  - See [deployment-and-alm.md § Worksheet W7](deployment-and-alm.md#worksheet-w7--packaging-decisions) for the two resulting worksheet shapes.
- **Must ask — Worksheet W7 (shape depends on the chosen method):**
  - **Push path:** publisher prefix only. No solution unique name. See [deployment-and-alm.md § W7 push method](deployment-and-alm.md#w7--push-method).
  - **Package path:** publisher name/prefix, solution unique/display name, solution version, **managed or unmanaged (always asked explicitly — never silently defaulted, even when the environment classification makes one choice likely)**, build path, checker, publish-changes.
- **Control version bump (always proposed, not silently applied):** before every publish to an environment — i.e. every time S10 is reached for a control that has already been published at least once — propose incrementing the manifest version's **third segment** by one, leaving the first two unchanged (e.g. `1.0.0` → `1.0.1` → `1.0.2`). The very first publish after scaffold ships the initial `1.0.0` as-is; the bump starts applying from the second deployment onward. Show the current version, the proposed version, and the reason as a row in Worksheet W7 — the user can approve or override it like any other worksheet row. See [deployment-and-alm.md § Versioning](deployment-and-alm.md#versioning).
- **Completion criteria:** publisher prefix confirmed (push path) or a real artifact exists at a **discovered** path (package path), and the control-version bump (and managed/unmanaged choice, package path) have both been explicitly confirmed. `pac auth who` output has been compared against the requested environment.
- **Must not:** authenticate without being asked; create a duplicate auth profile when a correct one exists; run any remote write; apply the version bump, assume a package type, or assume a deployment method without showing them in Worksheet W7 first.

**For `development`:** the same information (environment URL, publisher
prefix, method) is gathered once per environment if not already known,
but none of it becomes a worksheet **approval** step, and the control
version bump is computed and applied automatically rather than proposed.
See [S11](#s11--gate-c-deployment-confirmation) — this classification
never reaches it.

## S11 — GATE C: Deployment confirmation

Full detail: [deployment-and-alm.md § Gate C](deployment-and-alm.md#gate-c--deployment-readiness-report).
**Applies to `test`/`UAT`/`staging`/`production` only, always.** Readiness
report using
[`templates/deployment-readiness.md`](../templates/deployment-readiness.md), then a typed confirmation string. Single-use; invalidated by any of the changes in the [gate invalidation matrix](#gate-invalidation-matrix).

**`development` never reaches this stage — not even on the first
deployment to a brand-new environment.** No readiness report, no typed
string. Per
[deployment-and-alm.md § Development deployments run without a
confirmation gate](deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate),
a brief non-blocking heads-up line is shown instead, immediately before
S12 runs.

## S12 — Remote operation

Exactly one operation per confirmation (or, for `development`, per
heads-up line — see S11). Echo the command verbatim immediately before
running it, in every case.

## S13 — Post-deployment verification

Full detail: [deployment-and-alm.md § Post-deployment verification](deployment-and-alm.md#post-deployment-verification). Confirm success from real output (not from an async exit code alone); record the imported version; confirm the control/solution exists; re-confirm environment; report warnings verbatim; explain manual maker-portal steps; give a smoke-test checklist derived from the Gate A approved states; update the spec §19 deployment history.

---

## Gate invalidation matrix

| Event | Gate A | Gate B | Gate C |
|---|---|---|---|
| Any code, CSS, or manifest change, on a control that has had Gate A/B approved at least once (any session, any point in time) | not invalidated | not invalidated | **invalidated** |
| Converting a standard control to a React control | **invalidated** | **invalidated** | **invalidated** |
| A change on a control that has **never** had Gate A/B approved (still mid first-build) | full first-build rule applies — see [S5](#s5--gate-a-react-design-approval) | full first-build rule applies — see [S7](#s7--gate-b-manifest-approval) | N/A until first deployed |
| `refreshTypes` output changed | — | not invalidated (folded into the row above) | **invalidated** |
| Dependency change / `npm install` | — | — | **invalidated** |
| Rebuild (any) | — | — | **invalidated** |
| Version bump (control or solution) | — | — | **invalidated** |
| Auth profile changed / `pac auth select` | — | — | **invalidated** |
| Target environment changed | — | — | **invalidated** |
| Publisher or publisher prefix changed | — | — | **invalidated** |
| Package type (managed/unmanaged) changed | — | — | **invalidated** |
| Artifact path or artifact contents changed | — | — | **invalidated** |
| Import options changed (any modifier) | — | — | **invalidated** |
| New session / context compaction | preserved permanently, once granted | preserved permanently, once granted | **invalidated** |

Gate C never survives a session boundary: a resumed session cannot know whether the artifact on disk is still the one that was confirmed. Full detail on the first row — the policy that replaced this matrix's old per-change Gate A/B logic — is in [Gate A/B: one-time approval, not per-change](#gate-ab-one-time-approval-not-per-change), immediately below.

### Gate A/B: one-time approval, not per-change

**Gate A and Gate B apply exactly once per control: the first time it is
ever built.** Once a control has had Gate A approved and Gate B approved
(recorded in spec §18, from any session, at any point in its history),
no later code, CSS, or manifest change reopens either gate — a bug fix,
a restyle, a new or changed manifest property, a new feature-usage
declaration, anything. The change is applied, a summary is shown, and
work continues straight through validation and deployment with no "do
you approve" question of any kind for design or manifest.

**The one exception:** converting a standard control to a React control.
This is an architectural rewrite, not an update — a different base
interface, a rewritten `index.ts`, new `platform-library` entries, a
different bundling model — and getting it wrong produces a control that
fails at runtime (see
[manifest-design.md § Control metadata](manifest-design.md#control-metadata)).
It stays an explicit, separately-gated decision (full A, B, C) regardless
of how routine everything else has become, because it isn't "a change to
the control" in the sense this policy covers — it's replacing it.

**What this does not remove:**
- **Worksheets still ask when the request is genuinely unclear.** This
  policy removes the *sign-off* step after something is built, not
  ordinary requirement-clarification before building it. If it's not
  clear what a fix or update should actually do, ask — that's normal
  discovery, not a gate.
- **Gate C is untouched.** `development` deploys automatically per
  [deployment-and-alm.md § Development deployments run without a
  confirmation gate](deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate);
  `test`/`UAT`/`staging`/`production` still require the full readiness
  report and typed confirmation string, every time, regardless of Gate
  A/B history. For those classifications, the readiness report's Gate
  A/B status line should read as what it actually is — e.g. "approved
  (initial) YYYY-MM-DD — not re-verified on subsequent updates," not a
  bare "approved" that could be misread as "the current code was
  reviewed."
- **Transparency.** Before running validation/deployment, show a short
  summary of what changed — this is not a question and nothing waits for
  a reply, but the user should never learn what shipped only from the
  post-deployment report. Labeling the change (bug fix, design change,
  manifest change) using the categories below is useful for this summary
  even though it no longer decides whether to ask.
- **The spec stays accurate.** Log each post-approval update as a line in
  spec §5's iteration log (or §19 alongside the deployment it shipped
  with) even though it didn't reopen a gate — this is what lets a later
  session, or a skeptical user, see what's actually shipped since the one
  recorded approval, instead of having to trust that "approved" still
  describes the current code.

### Labeling a change: defect correction vs. design change

This distinction no longer decides whether Gate A reopens for an
already-approved control — nothing but the standard-to-React case does.
It's kept because it's still the right way to *describe* a change
honestly in the pre-run summary, and it still matters for a control still
mid-first-build (before Gate A has ever been granted, every iteration is
part of reaching that first "approved," logged in spec §5 as usual).

- **Defect correction:** the change makes the control finally do what was
  already recorded as approved (spec §2 purpose, §4 approved UI behavior,
  §5 approved states, §6 accessibility, §7 localization) — a broken
  localization string, a data-fetch bug that left an already-required
  field blank, a calculation bug, a CSS bug that broke an already-approved
  layout. The rendered output is visibly different from the broken
  version, but the change restores conformance rather than deviating from
  it.
- **Design change:** the change makes the control do or look like
  something that goes beyond what's already recorded as approved — a new
  state, a restyle, a new interaction, expanded scope, a spacing/color/
  font choice, or a "fix" that also changes something not required to
  correct the defect. CSS/styling changes default to this category —
  "update the control" covers both a logic fix and a genuine styling
  change, and the word "update" doesn't distinguish them.

Say which category applied, and why, in the pre-run summary — name the
spec section a defect correction restores, or name what's new about a
design change. This is honesty, not a gate: the work proceeds either way,
but the user should know which kind of change just shipped.

The Gate C column above describes the gate as it applies to
`test`/`UAT`/`staging`/`production` only. `development` never has a Gate
C confirmation to invalidate, first deployment or the hundredth — every
row in this column instead triggers the automatic re-verification
described in
[deployment-and-alm.md § Development deployments run without a
confirmation gate](deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate)
(auth re-checked, version recomputed, artifact rebuilt) before the next
push runs, with no question shown unless that re-verification finds an
actual mismatch.

---

## Worksheet protocol

- Batch related questions into one table per worksheet; never one question per message.
- Every row carries a **suggested value** and the **basis** for it, except values where a wrong guess would be harmful (publisher prefix, environment URL/ID, environment classification) — these are always asked blank.
- Before composing a worksheet, read the spec's [answered-questions index](../templates/control-spec.md) and the project files. A row already known is shown as `[known: <value>]`, not asked — but still shown, so the user can correct it.
- **Exception — per-deployment rows never go silent just because they're in the spec, for `test`/`UAT`/`staging`/`production`.** Environment (W8) and deployment method (W7) are shown as `[previously: <value>] — confirm again`, not `[known: <value>], not asked`, every time S10 runs for one of these classifications. A method or environment recorded from a prior deployment is the *starting suggestion*, not a setting that's been decided once and is now permanent — see [deployment-and-alm.md § Deployment method comes first](deployment-and-alm.md#deployment-method-comes-first).
- **Second exception — the opposite direction, for `development` only.** Once an environment is on record as `development` (any prior S10, any session), W8 and W7 are **not** re-shown at all on subsequent S10 passes for that target — the recorded values are reused silently, and only an actual anomaly (an auth mismatch, for instance) surfaces a question. This is a deliberate, narrower exception to "never go silent," scoped specifically to development targets because their deployments no longer go through Gate C either — see [deployment-and-alm.md § Development deployments run without a confirmation gate](deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate) for the full rule and its stated risk (classification is user-asserted and unverified).
- Four responses are always available: **approve all** · **edit** one or more rows (`edit R3: <value>`) · **reject** · **back** (returns to the previous stage).
- Free-text answers are honored over suggestions without argument. If a value will fail a known CLI rule, say so once with the rule, then use the user's value if they repeat it.

Worksheet inventory:

| ID | Stage | Covers |
|---|---|---|
| W1 | S1 | Requirement, host, template, framework, actions, inputs, outputs, bound column |
| W2 | S3-A | Project root, control name, namespace, output dir, npm install |
| W3 | S4 | States, responsive behavior, accessibility, localization, Fluent UI usage, design-system conventions, mock-data shape |
| W4 | S6 | Per-property rows |
| W5 | S6 | Dataset/property-set rows |
| W6 | S6 | Feature usage, external services, domains |
| W7 | S10 | Publisher, solution identity/version, managed/unmanaged, build path, checker, publish-changes |
| W8 | S10 | Environment URL/ID, classification, auth profile |

**W4/W5/W6 present as one combined S6 message, not three separate asks.**
They're split into three IDs here only so each row type can be cited
individually elsewhere in this skill (e.g. "edit P2" for a W4 row). In
practice: one property table (W4), followed immediately by the
dataset/property-set table (W5, only if the template is `dataset`),
followed immediately by the feature-usage/external-service table (W6,
only if either applies) — all in the same reply, with one **approve
all** / **edit** / **reject** / **back** response covering all of them
together. Never send W4, wait for a reply, then send W5.

---

## Existing-project change map

Triggered by "update", "modify", "fix", "add a property to", "bump the version of" an existing control, after the [S3 Branch B assessment](#s3--scaffold-or-existing-project-assessment) has run. Once a control has had Gate A and Gate B approved at any point in its history, per [Gate A/B: one-time approval, not per-change](#gate-ab-one-time-approval-not-per-change), **none of these re-open either gate** — the only question left is which stage to re-enter at, and whether Gate C applies.

| Change | Re-enter at | Gate re-required |
|---|---|---|
| UI-only tweak / styling change | S4 | C |
| New or changed manifest property | S6 | C |
| Add a feature (WebAPI, device) | S6 | C |
| Dependency update | S9 | C |
| Version bump only | S10 | C |
| Bug fix in component logic | S8 | C |
| Convert a standard control to React | S3 (explicit decision) | **A, B, C** — the one exception; see below |

Every row re-enters mid-flow and runs straight through to deployment with
no design or manifest sign-off — a styling change no longer reopens Gate
A, and a new manifest property no longer reopens Gate B, exactly the same
as a defect-correction bug fix. Show a short summary of what changed
before running (see [Gate A/B: one-time approval](#gate-ab-one-time-approval-not-per-change)),
but nothing waits for a reply. The **only** row that still requires full
A, B, and C is converting a standard control to React — that's an
architectural rewrite, not an update, and stays explicitly gated
regardless of how routine everything else has become.

"C" in this table means "S11 as it currently applies" — for
`test`/`UAT`/`staging`/`production`, that's the full Gate C readiness
report and typed confirmation, unchanged, always. For **any** `development`
target, "C" here means the automatic re-verification and heads-up
described in
[deployment-and-alm.md § Development deployments run without a
confirmation gate](deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate)
— the change still triggers a rebuild and a fresh push, just without a
blocking question.

Preservation rules, regardless of which row applies:
- Preserve unrelated user changes; never overwrite a file that has not been read.
- Show the planned file list before any refactor touching more than a couple of files.
- The goal is the requested change, not a rewrite to a preferred style — keep working code working.

---

## Resume protocol

1. On any invocation, look for `docs/pcf/<control-name>-spec.md` before asking anything.
2. If found, read §18 Workflow state first. Report the current stage and each gate's status back to the user in one short line.
3. Re-derive nothing already answered — pull from the answered-questions index.
4. Gate C is always `pending` or `invalidated` on resume, regardless of what the file says, because a new session cannot verify the artifact on disk still matches what was confirmed. Say so if the file shows a prior `approved` Gate C.
5. If the project files have drifted from what the spec describes — e.g. a manifest property the spec doesn't list, or a `control-type` mismatch — do not assume either side is right. Show the drift as a table (`Item | Spec says | Project actually has`) and ask which side is authoritative. Never silently overwrite the spec from the project, or the project from the spec.
6. If no spec exists at all for a project that already has a manifest, offer to generate one from the [S3 Branch B assessment](#s3--scaffold-or-existing-project-assessment). The user approves it before it becomes the reference — a reverse-engineered spec is a hypothesis until confirmed, not ground truth.

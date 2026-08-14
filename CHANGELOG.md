# Changelog

All notable changes to the PCF Control Builder skill/plugin are recorded
here. Versions correspond to `.claude-plugin/plugin.json` and
`marketplace.json`.

## 3.1.0

### Added: preview verification loop — failures are reported and retried until the user confirms they can see it

Reported from a real session: during S4 the preview build succeeded, the
page rendered **no elements at all**, and nothing in the skill noticed —
the user had to report the blank page themselves before the cause (React
error #321, "invalid hook call", from two React instances in the bundle)
was even looked for. The gate question had effectively been asked over a
preview nobody had checked. As of this version:

- **New non-negotiable rule 11** (previous rule 11 renumbered to 12):
  never present a command, build, or preview as working without checking
  that it actually worked — every exit status and output read, every
  screenshot looked at before it's shown.
- **On any failure** — non-zero exit, an error in the output, a browser
  console error, a blank or error-overlay page — the skill states it
  immediately with the **exact first error text**, applies one targeted
  fix, re-runs the **same** command and the **same** check, and asks the
  user to reload and confirm. This repeats until the user explicitly
  confirms they can see the preview. No iteration cap; the standard
  two-failed-fixes escalation rule still applies, at which point it stops
  guessing and reports what's been tried and what evidence is missing.
- **The render check and Gate A are now separate questions in a fixed
  order** — "can you see the preview rendering correctly at `<url>`?"
  first, "do you approve this React design…?" second, never merged into
  one message. A design approval given over an unverified or blank
  preview is **not** accepted as Gate A approval; the render check runs
  and the gate is re-asked. "ok" is not a render confirmation, the same
  way "looks good" was never a Gate A approval. Change iterations go back
  through the loop too, so an edit that breaks the preview can't become
  an approval request.
- **Explicitly banned:** retrying a failing command silently and showing
  only the run that worked, reporting partial success as success, handing
  over a `localhost` URL that was never confirmed to render, and
  substituting a static mock or a description of the intended UI for a
  preview that failed.
- `docs/pcf/<control>-spec.md` §5 gains a **preview render-check status**
  and a **preview-verification log** (signal, cause, fix, re-check result
  per failed round), so a resumed session knows whether the preview was
  ever confirmed.

### Fixed: the isolated preview workspace no longer ships a guaranteed blank page

The duplicate-React failure above wasn't bad luck — it's the default
outcome of the skill's own preview layout. The component lives outside
`preview/` but is imported into it, so it resolves `react` from the PCF
project's `node_modules` while the preview entry resolves its own copy.
`preview/vite.config.ts` is now generated with
`resolve.dedupe: ['react', 'react-dom']`, matching absolute aliases, and
`server.fs.allow` for the parent directory — the narrow fix, only those
two packages, applying to `vite build` as well as the dev server.

### Added: T28 — preview renders blank / no elements on the page

New troubleshooting branch with five ordered causes (two React copies;
nothing ever mounted; a throw during first render; rendered but invisible;
stale build), the evidence to collect for each, and a close condition that
requires the user's confirmation, not just a passing check.

## 3.0.0

### Changed (behavior, safety-relevant): Gate A and Gate B now apply once per control, not once per change

**Major reduction in a documented safety guarantee, made at explicit user
request after being shown the trade-off.** Through 2.1.1, Gate A (React
design approval) and Gate B (manifest approval) still reopened for any
update classified as a design change — a bug fix restoring already-approved
behavior was exempted (2.1.1), but a styling change, a new manifest
property, or any other design decision still required explicit
re-approval every time. The user reported this remained too much friction
for routine maintenance on an already-shipped, already-approved control
and asked for it removed entirely for updates, having been shown that
this specifically meant real design changes — not just bug fixes — would
also stop requiring a preview or sign-off. As of this version:

- Gate A and Gate B apply **once per control**: the first time it's ever
  built. This first approval is unchanged — you still see the rendered
  UI and the full manifest proposal and type approval for both.
- Once approved (recorded in spec §18, any session, any point in the
  control's history), **no later update reopens either gate** — a bug
  fix, a restyle, a new or changed manifest property, a new feature-usage
  declaration, anything. The change is applied, a summary is shown, and
  work proceeds straight through validation and deployment.
- **The one exception:** converting a standard control to a React
  control. This is an architectural rewrite (different base interface,
  rewritten `index.ts`, new `platform-library` entries) that can produce
  a control that fails at runtime if done incorrectly, so it stays fully
  gated (A, B, and C) regardless of the control's approval history.
- The defect-correction/design-change distinction introduced in 2.1.1 is
  **repurposed, not removed**: it no longer decides whether to ask (since
  post-approval updates never ask now, in either category), but it's kept
  as the required label in the pre-run summary — the user still sees
  whether an update was a fix or a genuinely new decision, just not as a
  blocking question. CSS/styling changes still default to the
  design-change label.
- Worksheets still ask when a request is genuinely ambiguous about *what*
  to build — this removes the sign-off step after something is built, not
  ordinary requirement clarification beforehand.
- `docs/pcf/<control>-spec.md` §18's Gate A/B status format changed from
  `approved YYYY-MM-DD` / `invalidated YYYY-MM-DD — <reason>` to
  `approved (initial) YYYY-MM-DD`, which never changes again for that
  control (short of the standard-to-React exception). Post-approval
  updates are logged in §5's iteration log instead, tagged
  `defect correction` or `design change`, so the spec still shows an
  honest history of what shipped since the one recorded approval.
- Gate C (deployment confirmation) is completely unaffected — `development`
  still deploys automatically per 2.1.0/2.1.1, and
  `test`/`UAT`/`staging`/`production` still require the full readiness
  report and typed confirmation string every time, regardless of Gate
  A/B history. For those classifications, the readiness report's Gate
  A/B fields now read `approved (initial) <date>` with an explicit note
  that later updates were not individually re-reviewed, rather than a
  bare "approved" that could be misread as "the current code was seen."

**The stated trade-off:** once a control clears its first design/manifest
review, nothing stops a wrong or unwanted change from reaching a
`development` environment before the user sees it — only the pre-run
summary and the post-deployment report show what happened, not a preview
approved in advance. Gate C for `test`/`UAT`/`staging`/`production`
remains a real backstop regardless, since it's untouched by this change.
See
[references/workflow.md § Gate A/B: one-time approval, not per-change](skills/pcf-control-builder/references/workflow.md#gate-ab-one-time-approval-not-per-change)
and
[README § One-time design/manifest approval](README.md#one-time-designmanifest-approval).

## 2.1.1

### Fixed: Gate A was reopening for bug fixes that restore already-approved behavior

The Gate A invalidation test was "did the rendered output/behavior change
from the last approved screenshot" — which sounds precise but gives the
wrong answer for the single most common maintenance task on a shipped
control: fixing a bug. A broken control necessarily renders differently
from what was intended, so that test forced Gate A to reopen on every bug
fix that actually fixed anything (e.g. a broken localization string, or a
WebAPI `$expand` bug leaving a required field blank) — exactly the
repetitive re-approval this skill exists to avoid on an already-approved,
already-shipped control.

Replaced the test with **defect correction vs. design change**: does the
change deviate from what's already recorded as approved (spec §2/§4/§5/§6/§7),
or does it restore conformance with it? A defect correction (the control
now finally does what was already specified) does not reopen Gate A, even
though the rendered output is visibly different from the broken version.
A design change (something new — a state, a restyle, an interaction, or
scope not in the approved spec) still reopens Gate A exactly as before.
When genuinely unsure which applies, the rule still defaults to
invalidating — this isn't a loophole for waving design changes through by
calling them a fix.

**Explicit guardrail added for CSS/styling:** "update the PCF control"
covers both a logic fix and a genuine styling change, and the word
"update" doesn't distinguish them. A CSS/styling edit now defaults to
design change and only counts as a defect correction when it's
demonstrably restoring an already-approved look that a CSS bug broke —
never merely because it arrived inside an "update" request. Without this,
the defect-correction exception above could have been over-applied to
real design changes (new spacing, new colors, a layout choice) just
because they were phrased as part of an "update." See
[examples/approval-gates-example.md](skills/pcf-control-builder/examples/approval-gates-example.md)
for both a defect-correction transcript and a contrasting styling-change
transcript that correctly still reopens Gate A.

See
[references/workflow.md § Labeling a change: defect correction vs. design change](skills/pcf-control-builder/references/workflow.md#labeling-a-change-defect-correction-vs-design-change)
(superseded in the next version — this distinction no longer gates Gate A
at all; see below)
for the full test, and
[examples/approval-gates-example.md](skills/pcf-control-builder/examples/approval-gates-example.md)
for a worked transcript matching the exact scenario that surfaced this
(a localization bug fix and a `$expand` data-fetch fix, neither of which
should have required re-approval).

## 2.1.0

### Changed (behavior, safety-relevant): development deployments never require confirmation, not even the first one

**Further reduction of the 2.0.0 policy, made at explicit user request.**
2.0.0 removed Gate C for *repeat* pushes to an already-established
`development` target, but still required the full readiness report and
typed `DEPLOY ...` string the first time any environment was used,
regardless of classification — the reasoning being that a brand-new
environment's values are genuinely unknown. The user asked for this
requirement removed too, explicitly including first-time deployment, in
order to avoid interrupting an agentic workflow for anything not related
to the actual business requirement. As of this version:

- `development`-classified deployments **never** go through Gate C — no
  readiness report, no typed confirmation, ever, including the first
  push to a brand-new environment.
- What's still asked, exactly once per environment: the values the tool
  cannot safely guess (environment URL, publisher prefix, and — for the
  package method — managed/unmanaged). This is classified explicitly as
  information-gathering, not a confirmation step, the same way Worksheet
  W1 asking what a control should do isn't a confirmation step. Once
  known, none of it is asked again for that target.
- `test`/`UAT`/`staging`/`production` are completely unaffected — full
  Gate C, every time, no exceptions, unchanged from every prior version.
- `pac solution publish` is unaffected for any classification, including
  `development` — it always requires its own separate confirmation,
  because it affects the whole environment rather than one control.
- Gate A and Gate B are unaffected — they confirm the work matches the
  actual requirement (UI design, manifest/data model), which this change
  treats as a categorically different question from deployment mechanics.
- Read-only `pac` commands (`pac auth who`, `pac auth list`,
  `pac solution list`, `pac solution check`) are now documented as never
  requiring confirmation, for any classification, since they cannot write
  to an environment. This was already close to true in practice; this
  version makes it an explicit, stated rule instead of an implicit one.

**The stated trade-off, unchanged in kind from 2.0.0 but now applying
from the very first deployment:** environment classification is
user-asserted and cannot be verified against Dataverse. If an environment
is ever misclassified as `development`, there is no remaining checkpoint
before code reaches it — not even a first-deployment review. See
[references/deployment-and-alm.md § Development deployments run without a
confirmation gate](skills/pcf-control-builder/references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate)
and
[README § Automatic deployment to development environments](README.md#automatic-deployment-to-development-environments).

## 2.0.0

### Changed (behavior, safety-relevant): development deployments no longer require confirmation once established

**This is a deliberate reduction in a documented safety guarantee, made
at explicit user request after being shown the trade-off.** Previously,
every push/import — including a `development`-classified target pushed
to for the tenth time in one session — required the full readiness report
and a typed `DEPLOY ...` confirmation string (or, from 1.1.0, a shortened
`confirm` for same-session repeats). As of this version:

- The **first** time any environment is used for a project, and **always**
  for `test`/`UAT`/`staging`/`production`, the full Gate C flow is
  unchanged: readiness report, typed confirmation string, no exceptions.
- For a `development`-classified environment already established for the
  project (recorded from any prior deployment, this session or an
  earlier one), later pushes/imports run **automatically** — no
  worksheet re-asks, no readiness report, no confirmation string of any
  kind. `pac auth who` is still verified before every push, silently,
  and only surfaces a question if it actually finds a mismatch. A
  one-line heads-up is shown immediately before running, and the full
  post-deployment report runs after, so the outcome is always visible —
  just not gated in advance.
- `pac solution publish` (publish-all-customizations) is **never**
  covered by this exception, for any classification — it always requires
  its own separate confirmation, because it affects the whole
  environment rather than one control.
- A specific dev environment can be put back under full confirmation at
  any time by telling the skill so explicitly; this is recorded as a
  per-environment override.
- This supersedes and removes the 1.1.0 same-session short-confirm
  mechanism, which is no longer needed now that established dev targets
  require no confirmation at all, in any session.

The 1.2.0 fix to Gate A's over-triggering (below) compounded with the
pre-2.0.0 Gate C behavior to make routine dev iteration — fix a bug,
redeploy, repeat — considerably more repetitive than intended. This
version addresses the deployment-confirmation half of that; 1.2.0
already addressed the Gate A half.

**The stated trade-off:** environment classification is asserted by the
user and cannot be verified against Dataverse itself. If an environment
is ever misclassified as `development`, this is what removes the
confirmation step for it. See
[references/deployment-and-alm.md § Development deployments run without a
confirmation gate](skills/pcf-control-builder/references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate)
for the full rule, and
[README § Automatic deployment to development environments](README.md#automatic-deployment-to-development-environments)
for the user-facing summary (further extended in 2.1.0, below, to also
cover the first deployment).

### Added: push/import commands can now be safely permission-allowlisted

Because the skill's own chat-level confirmation requirement is
independent of Claude Code's tool-permission layer, `pac pcf push` and
`pac solution import` can now be added to a permissions allowlist without
losing protection for anything above an established dev target — the
skill still asks in chat for `test`/`UAT`/`staging`/`production` and for
a first-time dev environment, regardless of what's allowlisted. Updated
the README's recommended permissions block accordingly.
`pac solution publish` and `pac auth create` remain deliberately excluded
from that recommendation.

## 1.2.0

### Fixed: Gate A was re-opening on non-visual code changes

The gate invalidation matrix and `SKILL.md`'s short summary said flatly
that any component edit invalidates Gate A. The existing-project change
map, elsewhere in the same skill, already had the correct nuance — a
logic-only bug fix with no visible/behavioral change should only
re-require Gate C. The two disagreed, and the blunt rule in `SKILL.md`
(loaded on every invocation) was winning, causing the design-approval
question to be re-asked on routine redeploys after a code fix that never
touched the UI. Fixed by aligning both to the same rule: CSS edits and
visible/behavioral component changes invalidate Gate A; a purely internal
change does not (when genuinely unsure, it still does). See
[SKILL.md § Gate invalidation](skills/pcf-control-builder/SKILL.md#non-negotiable-rules)
and
[references/workflow.md § Gate invalidation matrix](skills/pcf-control-builder/references/workflow.md#gate-invalidation-matrix).

### Added: Gate C same-session short confirm

For a repeat push in the same session to an unchanged `development`
target (the same scope as the 1.1.0 same-session fast path), Gate C's
required reply is now the single word `confirm` instead of retyping the
full `DEPLOY <name> TO <url>` string. The full readiness report is still
regenerated and shown every time — nothing about what the user reviews is
shortened, only the reply. Never applies to the first deploy of a
session, and never to test/UAT/staging/production, which always require
the full typed string.

*(Superseded in 2.0.0: established `development` targets no longer
require a confirmation reply at all, in any session — see
[Development deployments run without a confirmation gate](skills/pcf-control-builder/references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate).
The section this originally linked to no longer exists under this name.)*

## 1.1.0

### Reduced unnecessary prompting

- **S2 prerequisite inspection no longer double-asks.** Read-only version
  checks (`node --version`, `pac --version`, etc.) now run and report
  directly instead of being proposed as a separate chat turn on top of
  whatever the permission system already requires — see
  [references/workflow.md § S2](skills/pcf-control-builder/references/workflow.md#s2--prerequisite-and-repository-inspection).
- **W4/W5/W6 clarified as one combined S6 message**, not three separate
  asks — see
  [references/workflow.md § Worksheet protocol](skills/pcf-control-builder/references/workflow.md#worksheet-protocol).
- **New same-session fast path for repeat pushes to an unchanged
  development target.** When W8/W7 would otherwise re-confirm identical
  values against the same target within one session, they now collapse to
  a single restate-and-confirm line. Gate C is untouched — it still runs
  in full, every time, with its own typed confirmation string. Never
  applies across a session boundary or to test/UAT/staging/production.
  *(Superseded in 2.0.0 — see
  [Development deployments run without a confirmation gate](skills/pcf-control-builder/references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate);
  the section this originally linked to no longer exists under this
  name.)*
- **README now documents a recommended permissions allowlist** for
  read-only commands (`npm run build`, `pac auth who`, etc.), so
  installers aren't prompted on every routine build/inspection step.
  Deployment-write commands are deliberately left off that list.

### Script fixes

- `check-prerequisites.ps1`, `inspect-pcf-project.ps1`,
  `validate-pcf-project.ps1`: WARN-only findings no longer produce a
  non-zero exit code by default (a clean-but-imperfect result, like
  uncommitted git changes or an unused RESX string, is not a script
  failure). Added an opt-in `-FailOnWarn` switch on all three for callers
  that want the old strict behavior.
- All three scripts now exclude `node_modules`, `bin`, `obj`, `out`,
  `dist`, and `.git` from recursive project-file scans, instead of only
  `inspect-pcf-project.ps1`'s `package.json` search excluding
  `node_modules`.
- `validate-pcf-project.ps1`: a RESX file that fails to parse no longer
  causes every key in every *other* RESX file to be falsely reported as
  missing.
- `validate-pcf-project.ps1`: a localization key missing from only *some*
  declared RESX files (partial translation coverage) is now WARN instead
  of BLOCK; still BLOCK when missing from all of them.
- `validate-pcf-project.ps1`: the upward `package.json` search used for
  the duplicate-bundling heuristic no longer walks above the scanned
  project root, so it can't pick up an unrelated parent directory's
  `package.json`.
- `check-prerequisites.ps1`: `-IncludeVsCodeExtensions` (a `[bool]`
  parameter requiring `-IncludeVsCodeExtensions:$false` syntax) replaced
  with `-SkipVsCodeExtensions` (a standard switch).

### Content

- Added T27 (control deployed successfully but not visible in the
  maker/app) to
  [references/troubleshooting.md](skills/pcf-control-builder/references/troubleshooting.md).
- [templates/deployment-readiness.md](skills/pcf-control-builder/templates/deployment-readiness.md)
  now includes rows for the chosen deployment method and Gate A/B status.
- Added `license` field to `plugin.json`.

## 1.0.1

Version bump; no further detail recorded prior to this changelog's
introduction.

## 1.0.0

Initial public release: 13-stage gated workflow, three approval gates,
read-only inspection/validation scripts, and reference documentation for
manifest design, React preview architecture, build/test, deployment/ALM,
and troubleshooting.

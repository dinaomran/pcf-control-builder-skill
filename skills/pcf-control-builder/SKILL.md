---
name: pcf-control-builder
description: >-
  Build, modify, troubleshoot, package, and deploy Power Apps Component
  Framework (PCF) controls for Dataverse — field and dataset templates,
  React virtual controls and standard controls. Use when the user mentions
  PCF, Power Apps component framework, code component, ControlManifest,
  pac pcf, pcf-scripts, refreshTypes, a Dataverse solution containing a
  custom control, or asks to design, preview, scaffold, wire up, build,
  version, package, push, import, or publish such a control. Enforces a
  staged workflow with one-time React-design and manifest approval, plus
  deployment approval gates.
---

# PCF control builder

Turns a PCF request into a gated engineering workflow, not a one-shot code
dump: requirement discovery → prerequisites → scaffold/assessment →
standalone React preview → **approval gate** → manifest workshop →
**approval gate** → integration → local validation → deployment prep →
**typed confirmation gate** → remote operation → verification. The two
approval gates apply once per control, the first time it's built — later
updates to an already-approved control skip straight through them (see
[references/workflow.md § Gate A/B: one-time approval](references/workflow.md#gate-ab-one-time-approval-not-per-change)).

**The presence of deployment vocabulary in a request does not authorize a
deployment to `test`/`UAT`/`staging`/`production`.** "Publish my control,"
"ship it," "push this" all enter the workflow at the stage they describe
and stop at the next unmet gate for one of those classifications. Never
run a remote command against one on the strength of a word alone. **One
documented exception:** a push/import to a `development`-classified
target runs without a confirmation gate at all — including the first time
that environment is used, not just repeats — see
[references/deployment-and-alm.md § Development deployments run without a
confirmation gate](references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate).
This never applies to `test`/`UAT`/`staging`/`production`, and never to
`pac solution publish` (always its own, separately confirmed operation
regardless of classification) — those still require the words to be
backed by an actual, resolved gate.

## Non-negotiable rules

1. Installed CLI help is authoritative over memory. Query it as `pac <group> <verb> help` — **never** `--help` (that errors on this CLI family; see [references/official-source-policy.md](references/official-source-policy.md)).
2. Read `package.json` before running any npm script. Run only scripts that actually exist.
3. Read `ControlManifest.Input.xml` before proposing any manifest change.
4. Never install or update software (Node, npm, PAC CLI, .NET, MSBuild, VS, VS Code extensions). Never run `pac install latest`. Report and instruct; the user installs.
5. Never pass a secret (`--password`, `--clientSecret`, `--certificatePassword`) as a CLI argument. Interactive or `--deviceCode` sign-in only.
6. Never claim success from an asynchronous operation's exit code alone (`--async` proves submission, not completion).
7. Never skip, infer, or paraphrase a gate approval that is still required. Never treat an ambiguous reply as approval. This is not violated by [Gate A/B's one-time-approval policy](references/workflow.md#gate-ab-one-time-approval-not-per-change) or [Gate C's development exception](references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate) — those are documented cases where no gate is required in the first place, not gates being skipped.
8. Never re-ask a question already answered in `docs/pcf/<control-name>-spec.md` — **except values that can legitimately change between deployments** (target environment, deployment method). For `test`/`UAT`/`staging`/`production`, those are always re-confirmed at S10, every time, shown with the prior recorded value as the suggested default — never silently reused just because they're in the spec. Recording an answer in the spec is not the same as it becoming permanent. **For `development`, the opposite applies**: once an environment's URL/prefix/method are known (asked once, the first time — a wrong guess on these is harmful, so that one ask isn't skipped), W8/W7 are never shown again for that target — see [deployment-and-alm.md § Development deployments run without a confirmation gate](references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate). Both exceptions stop the instant something actually changes or doesn't match what's on record — an anomaly still gets surfaced and asked about, in either direction.
9. Never hand-edit generated typings (`ManifestTypes.d.ts`); regenerate with `refreshTypes`.
10. Never hard-code a version, environment URL, publisher, prefix, or `platform-library` version — read it from the project or current docs.
11. Never present a command, build, or preview as working without checking that it actually worked — read every exit status and every output, and look at every screenshot before showing it. **If anything fails or errors — a non-zero exit, an error in the output, a browser console error, a page that renders blank — say so immediately with the exact first error text, fix it, re-run the same check, and ask the user to retry.** Loop until the user explicitly confirms they can see the preview clearly; only then ask Gate A. A silent retry, a partial success reported as success, a URL handed over unverified, or a design approval collected over a preview nobody confirmed rendered all violate this. See [references/react-preview-and-architecture.md § Preview verification loop](references/react-preview-and-architecture.md#preview-verification-loop-before-gate-a).
12. New control scaffolds start the manifest at `1.0.0` (not the PAC-CLI default `0.0.1`). From the second publish onward, propose incrementing the manifest version's third segment by one before every deployment (e.g. `1.0.0` → `1.0.1`) — the first publish ships `1.0.0` unchanged. Always ask managed-vs-unmanaged explicitly at Worksheet W7, never inferred from environment classification alone. For `test`/`UAT`/`staging`/`production`, both the version bump and managed-vs-unmanaged are shown as worksheet rows for approval, every time, never applied silently. **For `development` — including the first deployment — the version bump is computed and applied automatically instead** (part of the no-confirmation-gate policy — see [references/deployment-and-alm.md § Development deployments run without a confirmation gate](references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate)), and reported after the fact rather than proposed beforehand. Managed-vs-unmanaged is still asked once if this dev target uses the package method and it's genuinely unknown — a wrong guess there is harmful — but that ask is information-gathering, not an approval step, and it never recurs for the same target. See [references/deployment-and-alm.md § Versioning](references/deployment-and-alm.md#versioning).

## State machine

13 stages, 3 gates. Read/write `docs/pcf/<control-name>-spec.md` at the start
and end of every stage — it is the resume mechanism across sessions and
context compaction. Full per-stage spec (inputs, files, commands, completion
criteria, "must not before approval") is in
[references/workflow.md](references/workflow.md).

```
S1 Requirement discovery        S8  PCF integration
S2 Prerequisite inspection      S9  Local validation + test
S3 Scaffold / assessment        S10 Deployment preparation
S4 React design + preview       S11 ══ GATE C: typed confirmation ══
S5 ══ GATE A: design approval ══  S12 Remote operation
S6 Manifest design proposal     S13 Post-deployment verification
S7 ══ GATE B: manifest approval ══
```

Two exceptions to the diagram above, both documented in detail elsewhere
and both worth knowing before reading anything else in this file:

- **GATE A and GATE B apply once per control** — the first time it's ever
  built. Once granted (any session, any point in the control's history),
  no later code, CSS, or manifest change reopens either one — not a bug
  fix, not a restyle, not a new manifest property. The one exception is
  converting a standard control to React, which is always fully re-gated
  because it's a rewrite, not an update. See
  [references/workflow.md § Gate A/B: one-time approval](references/workflow.md#gate-ab-one-time-approval-not-per-change).
- **GATE C is skipped entirely for `development`** — including its first
  deployment. It always applies for `test`/`UAT`/`staging`/`production`,
  with no exceptions. See
  [references/deployment-and-alm.md § Development deployments run without a
  confirmation gate](references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate).

Movement: forward requires the prior stage's completion criteria met and
recorded. "back" invalidates every downstream gate — this is an explicit
user request to redo a stage, not something a routine edit triggers on
its own. A request naming a later stage does not skip earlier ones —
enter there, report what's unsatisfied.

**Gate invalidation** (full matrix in
[references/workflow.md](references/workflow.md#gate-invalidation-matrix)):
any file/version/build/auth/environment/artifact change invalidates Gate C
where Gate C applies (`test`/`UAT`/`staging`/`production` only) — for
`development`, the same events instead trigger automatic re-verification
before the next push, with no question unless something actually doesn't
match. Gate A and Gate B are **not** invalidated by any of this, once
granted for a control — see the one-time-approval policy linked above.
Before running, still say plainly what kind of change this was — a
**defect correction** (the control now finally does what the approved
spec already called for, even though the rendered output looks different
from the broken version) or a **design change** (something new — a
state, a restyle, an interaction, or scope not in the approved spec).
This labeling no longer decides whether to ask; it's just honesty about
what shipped. CSS/styling changes default to design-change labeling.
Gate C never survives a session boundary — a resumed session always treats
it as unconfirmed.

## Routing table

| User intent | Entry stage | Read |
|---|---|---|
| New field or dataset control | S1 | [workflow.md](references/workflow.md), [manifest-design.md](references/manifest-design.md) |
| New React control | S1 | + [react-preview-and-architecture.md](references/react-preview-and-architecture.md) |
| Modify existing control | S3 (assessment), then per change type | [workflow.md § S3 Branch B](references/workflow.md#s3--scaffold-or-existing-project-assessment), [§ existing-project change map](references/workflow.md#existing-project-change-map) |
| React design / UI iteration | S4 | [react-preview-and-architecture.md](references/react-preview-and-architecture.md) |
| Manifest work (properties, dataset, features, resources) | S6 | [manifest-design.md](references/manifest-design.md) |
| Troubleshoot | any | [troubleshooting.md](references/troubleshooting.md) |
| Refresh types / build / test | S8–S9 | [build-and-testing.md](references/build-and-testing.md) |
| Package into a solution | S10 | [deployment-and-alm.md § package method](references/deployment-and-alm.md#w7--package-method) — the suggested default for test/UAT/staging/production |
| Development push | S10–S12 | [deployment-and-alm.md § push](references/deployment-and-alm.md#development-push) — the suggested default for development-classified targets |
| Import a solution | S10–S12 | [deployment-and-alm.md § import](references/deployment-and-alm.md#solution-import) |
| Publish all customizations | S10–S12 | [deployment-and-alm.md § publish](references/deployment-and-alm.md#publish-all-customizations) — always a separate, separately-confirmed operation |
| Version bump | S10 | [deployment-and-alm.md § versioning](references/deployment-and-alm.md#versioning) |
| Verify a deployment | S13 | [deployment-and-alm.md § verification](references/deployment-and-alm.md#post-deployment-verification) |

## The three gates — verbatim

Gate A and Gate B below apply **once per control — the first time it's
ever built.** For an existing control that's already had both approved
(any session, any point in its history), a later update does not trigger
either question — see
[references/workflow.md § Gate A/B: one-time approval](references/workflow.md#gate-ab-one-time-approval-not-per-change)
for the full policy and its one exception (converting a standard control
to React).

**Gate A — React design approval (end of S4, first build only).**

*Precondition:* the preview has been checked to render and the **user has
confirmed they can see it** — per rule 11 and the
[preview verification loop](references/react-preview-and-architecture.md#preview-verification-loop-before-gate-a).
Two separate questions, in order: "can you see the preview rendering
correctly at `<url>`?" first, then this gate. Never merged into one
message, and never asked while a command is failing or the page is blank.

Then ask exactly:

> "Do you approve this React design for manifest design and PCF integration, or should I change the UI or behavior first?"

Accept only an explicit affirmative to this question. "Looks okay," silence,
or approval of something else does not count — re-ask, naming the
ambiguity. On a change request: modify → refresh preview → re-verify and
re-confirm it renders → re-capture → re-check → re-ask, unlimited
iterations, each logged in the spec. The
**only** override is the literal instruction "Skip the React preview
approval gate" — record it verbatim with a timestamp; Gates B and C are
still required afterward.

**Gate B — Manifest approval (end of S6, first build only).** Show the complete 11-item
package from [manifest-design.md](references/manifest-design.md#gate-b-package)
(proposed XML/diff, property table, dataset config, type groups, feature
usage, external services, resources, prop/parameter mapping, file-change
list, refreshTypes reminder, host-compatibility warnings), then ask exactly:

> "Do you approve this manifest proposal for PCF integration?"

Row-level edits are supported (`edit P2: of-type=SingleLine.Email`) — apply,
re-show, re-ask. No manifest edit happens before explicit approval.

**Gate C — Deployment confirmation (end of S10, before S12).** Applies to
`test`/`UAT`/`staging`/`production` only, always. Show the readiness
report from
[templates/deployment-readiness.md](templates/deployment-readiness.md), then
require a **typed** string — never accept "yes," "ok," or similar:

- Test: `DEPLOY <target-identifier> TO <environment-url>`
- UAT/staging/production: `CONFIRM PRODUCTION IMPORT <target-identifier> <version> TO <environment-url>`
- `<target-identifier>` is the solution unique name for the package method, or the control name for push — see [references/deployment-and-alm.md § W7 push method](references/deployment-and-alm.md#w7--push-method).

**`development` never reaches this gate — not shown at all, not even on
the first deployment to a brand-new environment.** No readiness report,
no typed string, not even a short one. Replaced by a brief non-blocking
heads-up line before S12 runs, and the full
[Post-deployment verification](references/deployment-and-alm.md#post-deployment-verification)
report after. See
[references/deployment-and-alm.md § Development deployments run without
a confirmation gate](references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate)
for exactly what's still asked once (genuinely unknown values like a new
environment's URL or publisher prefix — information-gathering, not
approval) versus never asked at all.

Single-use. Any change listed in the invalidation matrix voids it — the
report regenerates and the gate re-asks. Full deployment-safety rules
(auth sequencing, push/import/publish scope, dangerous-modifier handling)
are in [deployment-and-alm.md](references/deployment-and-alm.md).

## Worksheet protocol

Batch related questions into one table per stage — never one question per
message. Every row shows a suggested value and its basis, except values
where guessing would be harmful (publisher prefix, environment URL,
classification), which are always asked blank. Rows already known from the
spec or project files are shown as `[known: <value>]`, not re-asked.

Four responses are always available: **approve all** · **edit** specific
rows · **reject** · **back**. Full worksheet inventory (W1–W8) is in
[workflow.md](references/workflow.md#worksheet-protocol).

## Safety summary

- `git status --short` before the first edit of a session; preserve
  unrelated changes; never commit/push/reset/clean/switch-branch/stash
  without an explicit request.
- Never overwrite a file that has not been read; show the file list before
  any multi-file refactor.
- No secret ever enters PCF source, the manifest, CSS, RESX, or the spec
  file. If a design needs a secret, the answer is a server-side
  intermediary, not client-side embedding.
- No remote write (push/import/publish/upgrade/delete) without a
  currently-valid Gate C confirmation, **except** a push/import to a
  `development` target — including its first deployment — which runs
  without that gate by design — see
  [references/deployment-and-alm.md § Development deployments run without
  a confirmation gate](references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate).
  `pac solution publish` is never covered by that exception, for any
  classification. No unrelated environment changes — verifying one
  control never means publishing all customizations or touching other
  solutions.
- Never rename or hand-edit the contents of a generated solution `.zip`.

## Reference index

- [references/workflow.md](references/workflow.md) — full per-stage spec, gate-invalidation matrix, worksheet inventory, resume protocol.
- [references/react-preview-and-architecture.md](references/react-preview-and-architecture.md) — preview harness construction and ReactControl/StandardControl integration rules.
- [references/manifest-design.md](references/manifest-design.md) — the full manifest workshop: properties, datasets, feature-usage, external services, resources.
- [references/build-and-testing.md](references/build-and-testing.md) — the three testing layers and the validation ladder.
- [references/deployment-and-alm.md](references/deployment-and-alm.md) — packaging, versioning, auth, push/import/publish safety, verification.
- [references/troubleshooting.md](references/troubleshooting.md) — evidence-first diagnosis branches T1–T26.
- [references/official-source-policy.md](references/official-source-policy.md) — source priority and the dated local CLI snapshot.
- [templates/control-spec.md](templates/control-spec.md) — the persistent per-control spec skeleton.
- [templates/manifest-proposal.md](templates/manifest-proposal.md) — the fixed Gate B package layout.
- [templates/deployment-readiness.md](templates/deployment-readiness.md) — the fixed Gate C report + confirmation strings.
- [examples/field-control-example.md](examples/field-control-example.md), [examples/dataset-control-example.md](examples/dataset-control-example.md), [examples/approval-gates-example.md](examples/approval-gates-example.md), [examples/package-method-dev-example.md](examples/package-method-dev-example.md) — worked transcripts.
- [scripts/check-prerequisites.ps1](scripts/check-prerequisites.ps1), [scripts/inspect-pcf-project.ps1](scripts/inspect-pcf-project.ps1), [scripts/validate-pcf-project.ps1](scripts/validate-pcf-project.ps1) — read-only inspection scripts; never install, authenticate, or write to an environment.

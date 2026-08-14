<!--
TEMPLATE: docs/pcf/<control-name>-spec.md

Copy this file to docs/pcf/<control-name>-spec.md in the user's project (not
inside the skill directory) and fill it in as the workflow progresses. Read
it FIRST on every invocation, before asking anything — it is how the skill
avoids re-asking a settled question and how a new session resumes mid-workflow.

>>> NO CREDENTIALS IN THIS FILE. <<<
Never record: passwords, tokens, client secrets, certificate passwords,
connection strings with embedded credentials, cookies, or anything from the
PAC CLI auth store. Environment URLs, tenant names, publisher prefixes, and
solution names are NOT secrets and belong here.
-->

# Control specification: <ControlName>

Spec version: 1 | Created: <YYYY-MM-DD> | Last updated: <YYYY-MM-DD>

## 18. Workflow state
<!-- Kept first on purpose: a resuming session reads this before anything else. -->

Current stage: `<S1..S13>`

| Gate | Status |
|---|---|
| A — React design approval | `pending` \| `approved (initial) YYYY-MM-DD` \| `overridden YYYY-MM-DD — "<exact user wording>"` |
| B — Manifest approval | `pending` \| `approved (initial) YYYY-MM-DD` |
| C — Deployment confirmation | `pending` \| `approved YYYY-MM-DD — <operation>` \| `invalidated YYYY-MM-DD — <reason>` |

Gate A and Gate B apply **once per control**, per the skill's Gate A/B
one-time-approval policy. Once either shows `approved (initial) <date>`, it stays that way
permanently for this control — later code/CSS/manifest updates are
logged in §5's iteration log, not re-approved, and do not change this
status. The one exception is converting a standard control to React,
which resets both to `pending` and re-runs the full first-build gates.
Gate C keeps its normal per-deployment lifecycle and can still show
`invalidated` — see the gate invalidation matrix in workflow.md.

Gate A iteration count: `<n>` (each **pre-approval** UI change round
increments this; post-approval updates are logged in §5 too but don't
increment this counter — see §5 for both logs)

## 1. Identity

- Control name: `<ControlName>`
- Namespace: `<Namespace>`
- Constructor: `<ControlName>`
- Template: `field` \| `dataset`
- Framework: `react` \| `none`
- Actual `control-type` read from manifest: `<standard | virtual>` <!-- must match framework; if it doesn't, flag it -->

## 2. Business purpose

> <requirement, quoted in the user's own words>

## 3. Target host

- Host: `model-driven app` \| `canvas app` \| `custom page` \| `<other>`
- Manifest features this host is known to support (from current official docs, checked on `<date>`): <!-- fill -->

## 4. Approved UI behavior

<!-- Layout, interactions, what each user action does -->

## 5. Approved component states

| State | Applies? | Behavior | Gate A iteration approved in |
|---|---|---|---|
| Normal | | | |
| Empty | | | |
| Loading | | | |
| Error | | | |
| Disabled | | | |
| Read-only | | | |

Preview render check (S4): `not run` \| `confirmed YYYY-MM-DD — user
confirmed the preview renders` \| `failing — <one-line summary>`

<!-- Gate A is not asked while this says `not run` or `failing`. Re-set to
     `not run` whenever the component or preview harness changes, until the
     user re-confirms. -->

Preview-verification log — one row per failed round, per
[react-preview-and-architecture.md § Preview verification loop](../references/react-preview-and-architecture.md#preview-verification-loop-before-gate-a):

| # | Date | Failure signal (exact first error) | Cause identified | Fix applied | User re-check result |
|---|---|---|---|---|---|

Iteration log — rows before Gate A's initial approval are part of
reaching it; rows after are post-approval updates that shipped without
reopening it (see §18):

| # | Date | Type (`pre-approval` \| `defect correction` \| `design change`) | What changed | Screenshot(s) |
|---|---|---|---|---|
| 1 | | | | |

## 6. Accessibility requirements

- Keyboard model: <!-- fill -->
- ARIA roles/labels: <!-- fill -->
- Focus behavior: <!-- fill -->
- High-contrast notes: <!-- fill -->

## 7. Localization

- Languages / LCIDs: <!-- fill -->
- RESX files: <!-- fill -->
- Key naming convention: <!-- fill -->

## 8. Template and framework

<!-- Recorded above in §1 Identity (template, framework, actual control-type).
     This heading exists so section numbers stay contiguous with the rest of
     this file; there is no separate content to fill in here. -->

## 9. Manifest properties

<!-- Paste the approved property table verbatim from the Gate B package. -->

| ID | name | purpose | of-type/group | usage | required | default | React prop | context.parameters | output | validation |
|---|---|---|---|---|---|---|---|---|---|---|

## 10. Dataset and property-set configuration

Applicable: `yes` \| `no — field template`

<!-- If yes: data-set name(s), property-set columns, sorting, filtering, paging,
     selection behavior, loading/empty states, refresh-loop guard. -->

## 11. Feature usage

| Feature | required | Justification (actual code behavior) | Fallback if `required="false"` |
|---|---|---|---|

`<feature-usage>` block omitted: `yes` \| `no`

## 12. External services

<!-- Domain(s), host support, licensing note, CORS/auth approach, secret-exposure
     assessment. Never a credential value — see the banner at the top of this file. -->

## 13. Manifest resources

| Type | Path | Order/Version | Exists? | Action | Why required | Host availability |
|---|---|---|---|---|---|---|

## 14. Input/output mapping

| React prop | context.parameters | getOutputs field |
|---|---|---|

## 15. Publisher and solution choices

- Publisher display name: <!-- fill -->
- Publisher prefix: <!-- fill -->
- Solution unique name: <!-- fill (package method); n/a for push -- pac pcf push uses its own default solution --> <!-- must differ from the PCF project name -->
- Solution display name: <!-- fill -->
- Solution version policy: <!-- fill -->
- Managed / unmanaged policy: <!-- fill --> <!-- asked explicitly at every S10, per-deployment -- see spec §19 for what was actually chosen each time -->

## 16. Build and deployment decisions

- Control version scheme: `<default: start 1.0.0 at scaffold; +1 to the third segment before each publish after the first (1.0.0 -> 1.0.1 -> 1.0.2) | override: fill>`
- Current manifest version: <!-- fill --> <!-- keep in sync with ControlManifest.Input.xml; bumping it invalidates Gate C -->
- Build path: `dotnet build` \| `MSBuild (<discovered path>)`
- Artifact path pattern (discovered, not assumed): <!-- fill -->
- Power Apps Checker policy: <!-- fill -->
- Publish-changes policy: <!-- fill -->

## 17. Environments

| Classification | URL / ID |
|---|---|
| Development | |
| Test | |
| UAT | |
| Staging | |
| Production | |

## 19. Deployment history

<!-- Append-only. -->

| Date | Operation | Environment | Solution version | Control version | Outcome | Verification result |
|---|---|---|---|---|---|---|

## 20. Open questions and known limitations

<!-- Seed with unresolved prerequisite blocks, e.g.:
- Node.js not installed as of <date> — React preview and PCF build unavailable until resolved. -->

## Answered-questions index

<!-- Keyed by worksheet row ID so the never-re-ask check is a lookup, not a re-read
     of prose. Add a row every time a worksheet is approved or edited. -->

| Row ID | Question | Answer | Set at stage | Date |
|---|---|---|---|---|

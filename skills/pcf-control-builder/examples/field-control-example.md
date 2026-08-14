# Worked example: single bound-text field control

A condensed, end-to-end transcript shape for a React field control with one
bound property. All values are placeholders — this shows *sequence and
shape*, not copy-paste content. Full rules for each step are in the linked
references.

## S1-S2: discovery + prerequisites

Worksheet W1 batches purpose/host/template/framework. Then
[`scripts/check-prerequisites.ps1`](../scripts/check-prerequisites.ps1) runs
and its BLOCK/WARN table is shown before anything else happens. If Node is
missing, this is where the workflow stops and reports it — see
[workflow.md § S2](../references/workflow.md#s2--prerequisite-and-repository-inspection).

## S3: scaffold (new project)

Worksheet W2 (project root, control name, namespace, output dir, npm
install). Then, in PowerShell:

```powershell
pac pcf init --namespace <Namespace> --name <ControlName> --template field --framework react --outputDirectory "<path>" --run-npm-install
```

`--framework` and `--run-npm-install` are always explicit — neither has a
default that should be relied on. Immediately after, read (don't modify)
`package.json`, `ControlManifest.Input.xml`, `tsconfig.json`, `index.ts`.
The scaffold generated `ControlManifest.Input.xml` with `version="0.0.1"` —
edit it to `version="1.0.0"` (this skill's fixed starting convention) and
show the one-line diff. Then create `docs/pcf/<ControlName>-spec.md` from
[`templates/control-spec.md`](../templates/control-spec.md), recording the
control version scheme in §16.

## S4: React design + preview

Worksheet W3 (states, accessibility, localization, Fluent usage, mock-data
shape). Build `<ControlName>Component.tsx` with typed props, zero
`ComponentFramework` coupling, and scoped CSS in `<ControlName>.css`. Cover
normal/empty/loading/error/disabled/read-only as applicable. Stand up the
preview harness (existing Storybook/Vite, or an isolated `preview/`
workspace — see
[react-preview-and-architecture.md](../references/react-preview-and-architecture.md#isolated-preview-workspace-layout)).
Show the command, the local URL, a screenshot per state (only if a
screenshot capability is actually available — otherwise say so), and an
explicit list of what's mocked (here: the bound URL value and the submit
callback).

Then verify it before showing it as ready: read every command's exit
status and output, check the page actually rendered (non-empty mount root,
no console error, no error overlay), and report any failure with its exact
error text before anything else. Close the stage with the render check:

> "Can you see the preview rendering correctly at `http://localhost:5173` —
> every state visible, no blank page and no error overlay?"

Anything other than an explicit yes loops: fix → re-run the same check →
re-ask. See
[react-preview-and-architecture.md § Preview verification loop](../references/react-preview-and-architecture.md#preview-verification-loop-before-gate-a).

## S5: Gate A

Only after the render check is confirmed, and as a **separate** question:

> "Do you approve this React design for manifest design and PCF
> integration, or should I change the UI or behavior first?"

Assume an explicit **approve** here. Recorded in spec §18/§5.

## S6: manifest proposal

Worksheet W4 for the one property. Example row (illustrative values):

| ID | name | purpose | of-type | usage | required | React prop | context.parameters | getOutputs |
|---|---|---|---|---|---|---|---|---|
| P1 | urlValue | The URL the control launches | SingleLine.URL | bound | true | `props.urlValue` | `context.parameters.urlValue.raw` | `urlValue` |

Resources table lists `code` (preserved from scaffold), `css`, `resx`, and
the scaffold's generated `platform-library` React entry (version read from
the manifest, not invented). No `feature-usage` block — this control makes
no `context.webAPI` calls and needs no device/utility feature, so the block
is **omitted entirely**, not left empty.

Full package assembled via
[`templates/manifest-proposal.md`](../templates/manifest-proposal.md).

## S7: Gate B

> "Do you approve this manifest proposal for PCF integration?"

Assume an explicit **approve**. Recorded in spec §9-§14.

## S8: integration

`ControlManifest.Input.xml` gets the approved property. `index.ts` becomes
the thin adapter: reads `context.parameters.urlValue.raw`, builds props,
returns the element from `updateView`. `getOutputs` returns the committed
value; `notifyOutputChanged` fires only from the component's `onChange`
handler, never during render. `npm run refreshTypes` runs (script exists in
this scaffold).

## S9: validation

Ladder from [build-and-testing.md](../references/build-and-testing.md):
refreshTypes -> type check -> lint (if configured) -> dev build ->
production build -> local preview -> `npm start` harness -> unit tests (if
present) ->
[`scripts/validate-pcf-project.ps1`](../scripts/validate-pcf-project.ps1).
Each step reported as ran/skipped/failed/blocked.

## S10: packaging

The environment (`https://contoso-dev.crm4.dynamics.com`), classification
(`development`), and publisher prefix (`contoso`) are genuinely unknown
the first time this project deploys — asked once, as information-gathering,
not a confirmation to deploy (a wrong guess on any of these would be
harmful). `pac auth list` / `pac auth who` compared against the answer.

**Deployment method proposed:** `pac pcf push` — basis: development
classification (see
[deployment-and-alm.md § Deployment method comes first](../references/deployment-and-alm.md#deployment-method-comes-first)).
This is shown as a worksheet row, not silently assumed; the user could
instead ask for the full package method (e.g. to produce a managed
artifact for later promotion even from dev), which would follow
[deployment-and-alm.md § package method](../references/deployment-and-alm.md#w7--package-method)
— `pac solution init` / `add-reference` / `dotnet build` / discovered
`.zip` / `pac solution import` — instead of everything below.

Worksheet W7, push shape: **publisher prefix only** — no solution unique
name. No display name, version, build-path, or managed/unmanaged questions
either — push is unconditionally unmanaged, stated rather than asked. The
**control-version row**: this is the control's first-ever publish (spec
§19 deployment history is empty), so the version used is `1.0.0`
unchanged — the bump rule only starts from the second deployment onward,
and even then it's computed and applied automatically, not proposed (see
S11 below).

## S11: no Gate C for development

Classification came back `development`, so — per
[deployment-and-alm.md § Development deployments run without a
confirmation gate](../references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate)
— **S11 is skipped entirely, including on this first deployment.** No
readiness report, no typed `DEPLOY ...` string. Once the Worksheet
W8/W7 answers above are in hand, S10 flows straight into S12 with a
one-line heads-up:

> Pushing ContosoUrlLauncher v1.0.0 to
> https://contoso-dev.crm4.dynamics.com (development, no confirmation
> required)...

## S12: remote operation

The command runs immediately after the heads-up line above — no reply is
waited for. Run from the PCF project root (push has no `--path`):

```powershell
pac pcf push --environment "https://contoso-dev.crm4.dynamics.com" --publisher-prefix "contoso"
```

## S13: verification

`pac auth who` re-confirms the environment; any push output warnings
reported verbatim; manual maker-portal step noted (the control still needs
to be added to a form and the form published — push alone does not do
this); smoke-test checklist derived from the Gate A states; spec §19
deployment-history row appended (recording control version `1.0.0`,
method `push`). This report is the primary place the user actually
reviews what happened, since nothing paused for review beforehand.

## Same-session redeploy (no confirmation gate)

Still in the **same chat**, the user immediately asks for one more small
fix to `urlValue`'s validation and to push again. Re-entry is still S8 →
S9 → S10 per the change-class map (a logic-only fix that doesn't change
visible behavior, so Gate A isn't re-opened; a CSS or rendering change
would re-open it). At S10, the target
(`https://contoso-dev.crm4.dynamics.com`) is now on record in spec §17 as
`development`, from the push that just ran — so per
[deployment-and-alm.md § Development deployments run without a
confirmation gate](../references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate),
none of W8, W7, or Gate C is shown. `pac auth who` is checked silently and
matches; the control-version bump (`1.0.0` → `1.0.1`) is computed and
applied automatically. The user sees:

> Pushing ContosoUrlLauncher v1.0.1 to
> https://contoso-dev.crm4.dynamics.com (development, no confirmation
> required)...

`pac pcf push` runs immediately after that line — no reply is waited for.
The full [S13 verification](#s13-verification) report runs afterward,
exactly as it did for the first push, so the user still sees the actual
outcome, version, and any warnings.

## On a later redeploy (new session)

The user closes the chat and comes back the next day asking to fix a
different bug. This is **not** the full, ask-everything path — the
environment is still on record from yesterday, and the no-confirmation
policy has no session-boundary restriction (unlike Gate A/B, which are
also preserved across sessions, or the old spec-answer reuse rules for
values that aren't per-deployment). What actually happens:

- **Re-entry point** per the [change-class map](../references/workflow.md#existing-project-change-map)
  — same as the same-session case above.
- **W8 is not shown.** The spec already records
  `https://contoso-dev.crm4.dynamics.com` as `development`; `pac auth
  who` is checked automatically and, since it still matches, nothing is
  asked. If it *didn't* match — a different profile now active, say — that
  mismatch would stop and ask, same as it always would.
- **W7 is not shown.** Method (`push`) and publisher prefix (`contoso`)
  are reused from spec §16 without being re-asked.
- **Control version** is computed and applied automatically: `1.0.1` →
  `1.0.2`.
- **No Gate C.** The heads-up line and immediate push happen exactly as
  in the same-session case above.

This reflects this skill's current `development` policy: Gate C never
applies to a `development` target, not even its first deployment, and
W8/W7 stop being re-asked the moment an environment's values are known —
which can be the very first S10 pass, not just later ones.
`test`/`UAT`/`staging`/`production` are unaffected by any of this — see
[package-method-dev-example.md](package-method-dev-example.md) for a
worked package-method transcript, where the same no-Gate-C rule applies
to a dev target even though the method (package, not push) is different
— classification is what decides this, not method.

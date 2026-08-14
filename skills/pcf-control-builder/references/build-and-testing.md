# Build and test strategy

## Table of contents
- [Read package.json first](#read-packagejson-first)
- [Three distinct testing layers](#three-distinct-testing-layers)
- [Validation ladder](#validation-ladder)
- [Reporting](#reporting)

## Read package.json first

Enumerate the `scripts` object and run **only** scripts that exist. Typical
scaffold scripts are `build`, `clean`, `rebuild`, `start`, `refreshTypes`,
`lint` — but this varies by PAC CLI template version and is **unverified**
in the abstract; it must be read from the actual `package.json` every time,
never invoked from memory. [`scripts/inspect-pcf-project.ps1`](../scripts/inspect-pcf-project.ps1)
reports the real script list.

## Three distinct testing layers

| Layer | What it proves | What it cannot prove |
|---|---|---|
| **1. React design preview** | Visual design, states, interaction, accessibility of the component in isolation | Nothing about PCF wiring, manifest correctness, or host behavior |
| **2. PCF test harness** (`npm start`) | Manifest parses; the control loads; properties surface; basic interaction in the harness | Real Dataverse behavior. Several platform APIs are absent or stubbed in the harness — notably `webAPI`, parts of `utils`/`device`/`navigation`, and real security/read-only signals |
| **3. Environment-integrated test** | Actual host behavior after push or import | — |

State which layer a given result came from. "It works in the harness" is
never presented as "it works" — see [troubleshooting.md T18/T19](troubleshooting.md#t18t19--pcf-test-harness-limitations)
for the harness-limitation diagnosis pattern.

## Validation ladder

Run in order at S9. Stop at the first failure and route to
[troubleshooting.md](troubleshooting.md). Skip a step only when its
prerequisite script/config does not exist — and report the skip as a skip,
not a pass.

1. **Type generation** — `npm run refreshTypes` (if present).
2. **Type check** — via the build, or `tsc --noEmit` if the project supports
   it.
3. **Lint** — only if a lint script/config genuinely exists
   ([`scripts/inspect-pcf-project.ps1`](../scripts/inspect-pcf-project.ps1)
   reports the detected style).
4. **Development build** — `npm run build`.
5. **Production build** — the project's actual production form; read the
   real flag from `package.json` rather than assuming a specific
   `--buildMode` argument exists.
6. **Local preview** — the React preview harness (Layer 1).
7. **PCF test harness** — `npm start` (Layer 2); confirm the control
   renders; exercise the approved states.
8. **Unit tests** — if a test script exists.
9. **Manifest/resource consistency** —
   [`scripts/validate-pcf-project.ps1`](../scripts/validate-pcf-project.ps1):
   every `<resources>` path exists; every manifest localization key exists
   in every RESX; property names are unique.
10. **Solution artifact** — only at S10, see
    [deployment-and-alm.md](deployment-and-alm.md).
11. **Power Apps Checker** — `pac solution check`, for release-bound
    workflows; requires an environment and is a remote **read** operation.
    Read-only `pac` commands never require confirmation — they can't
    write to an environment — so this runs and reports, the same as any
    other diagnostic step.

## Reporting

Report each step as **ran** / **skipped** / **failed** / **blocked**. A
skipped step is never reported as a pass. If Node.js is unavailable (per
[`scripts/check-prerequisites.ps1`](../scripts/check-prerequisites.ps1)),
steps 1–8 are all reported as **blocked**, not skipped — the distinction
matters because "skipped" implies a choice was made and "blocked" implies
the user still needs to act.

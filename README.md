# PCF Control Builder

A Claude Code skill (distributed as a plugin) that turns "build me a PCF
control" into a **gated, resumable engineering workflow** instead of a
one-shot code dump.

It guides you end-to-end through creating, previewing, integrating,
troubleshooting, packaging, and safely deploying [Power Apps Component
Framework (PCF)](https://learn.microsoft.com/power-apps/developer/component-framework/overview)
controls for Dataverse — field and dataset templates, React virtual
controls, and standard controls — with explicit approval gates the first
time a control's UI is finalized and the first time its manifest is
built. Once a control has cleared those two approvals, later updates
(bug fixes, styling changes, new properties — anything short of an
architectural rewrite) ship without asking again — see
[One-time design/manifest approval](#one-time-designmanifest-approval).
Deployment to `test`/`UAT`/`staging`/`production` always requires a
separate, explicit confirmation regardless of the above; a
`development`-classified environment deploys automatically, with no
confirmation step, including its first deployment — see
[Automatic deployment to development environments](#automatic-deployment-to-development-environments).

## What it does

Instead of generating a full control in one pass, the skill works through
13 stages with 3 hard approval gates:

```
S1  Requirement discovery         S8  PCF integration
S2  Prerequisite inspection       S9  Local validation + test
S3  Scaffold / assessment         S10 Deployment preparation
S4  React design + preview        S11 ══ GATE C: typed confirmation ══
S5  ══ GATE A: design approval ══ S12 Remote operation
S6  Manifest design proposal      S13 Post-deployment verification
S7  ══ GATE B: manifest approval ══
```

- **Gate A** — you see and approve the actual React UI (with a runnable
  preview) before any PCF-specific wiring happens. Applies once per
  control, the first time it's built — see
  [One-time design/manifest approval](#one-time-designmanifest-approval).
  Before that question is even asked, the preview has to be *verified to
  render* and you have to confirm you can see it — see
  [Preview failures are reported, not hidden](#preview-failures-are-reported-not-hidden).
- **Gate B** — you see the full manifest proposal (properties, datasets,
  features, resources) before anything is written to
  `ControlManifest.Input.xml`. Also applies once per control.
- **Gate C** — before any push or import to `test`/`UAT`/`staging`/
  `production`, you must type an exact confirmation string naming the
  solution, version, and target environment. It's single-use and
  invalidated by any subsequent change. **One documented exception:**
  `development`-classified deployments never go through Gate C, including
  the first push to a brand-new dev environment — see
  [Automatic deployment to development environments](#automatic-deployment-to-development-environments)
  below. `pac solution publish` (which affects an entire environment, not
  just one control) always requires confirmation, for any classification.

Between stages, the skill reads your project instead of guessing: it checks
installed tooling versions, reads `package.json` before running any script,
reads the existing manifest before proposing changes, and never hard-codes
a version number, environment URL, or publisher prefix.

## Who it's for

Developers and consultants building or maintaining PCF controls for
Dataverse/Power Apps who want an assistant that:

- Won't silently modernize, rewrite, or "clean up" an existing control.
- Won't call a remote `pac` command against `test`/`UAT`/`staging`/
  `production` without your explicit, typed confirmation. (Pushes to a
  `development` environment run automatically, by design — see
  [Automatic deployment to development environments](#automatic-deployment-to-development-environments).)
- Won't guess CLI syntax or manifest schema from memory when it can check
  the installed tooling or current docs instead.

It assumes you already have (or are willing to install yourself) the
Power Platform CLI (`pac`), Node.js/npm, and — for solution packaging — the
.NET SDK or MSBuild. The skill checks for these and reports what's missing;
it never installs anything for you.

## Installation

### Option A — Install as a Claude Code plugin (recommended)

Works the same way in the Claude Code CLI and the VS Code / JetBrains
extensions.

**From the Claude Code chat UI:**

1. Open the slash-command menu and select **Manage plugins** (or run
   `/plugin`).
2. Go to the **Marketplace** tab and add this repository's URL:
   `https://github.com/dinaomran/pcf-control-builder-skill`
3. Find **pcf-control-builder** in the list and click **Install**.

**From the command line, inside a Claude Code chat:**

```text
/plugin marketplace add dinaomran/pcf-control-builder-skill
/plugin install pcf-control-builder@pcf-tools
```

If Claude Code reports that the plugin needs activating, run
`/reload-plugins`.

### Option B — Copy the skill folder directly

If you'd rather not use the plugin/marketplace system, copy
[`skills/pcf-control-builder/`](skills/pcf-control-builder/) into:

- `~/.claude/skills/pcf-control-builder/` — available in every project, or
- `<your-project>/.claude/skills/pcf-control-builder/` — available in that
  project only

Claude Code picks up skill folders live; no restart is needed.

## How to invoke it

Once installed, you don't need a special command — the skill triggers
automatically whenever your request matches PCF/Power Apps component
framework work. Just describe what you need, for example:

> "Build me a PCF field control that lets a user pick a color for a
> Dataverse text column."

> "I have an existing PCF dataset control — add a filter property and
> refresh the manifest types."

> "Package and push my PCF control to my dev environment."

The skill's trigger vocabulary includes terms like PCF, Power Apps
component framework, `ControlManifest`, `pac pcf`, `pcf-scripts`,
`refreshTypes`, and verbs like design, scaffold, build, version, package,
push, import, and publish. If you want to be explicit, you can also say
"use the PCF control builder skill" at the start of your request.

## Reducing permission prompts

Claude Code asks for approval before running any shell command that isn't
already allowlisted in your settings. This is a separate layer from the
skill's own Gate C — allowlisting a command here only removes Claude
Code's own popup; it does not by itself grant the skill permission to
deploy anywhere. The skill's chat-level confirmation requirement (typed
`DEPLOY ...` / `CONFIRM PRODUCTION IMPORT ...`) still applies on top of
whatever's allowlisted here, for `test`/`UAT`/`staging`/`production` — see
[Automatic deployment to development environments](#automatic-deployment-to-development-environments)
for the one classification where it doesn't.

Read-only commands (`npm run build`, `node --version`, `pac auth who`,
`pac solution list`, `pac solution check`, `git status`, …) never need a
popup at all — they can't write to anything. Push/import commands *can*
safely be allowlisted here too, because the skill's own confirmation
requirement is independent of this layer and still governs
`test`/`UAT`/`staging`/`production` regardless of what's allowlisted. A
starting set:

```json
{
  "permissions": {
    "allow": [
      "Bash(node --version)", "Bash(npm --version)",
      "Bash(npm run build*)", "Bash(npm run refreshTypes*)",
      "Bash(npm run lint*)", "Bash(npm start*)", "Bash(npm ci*)",
      "Bash(pac --version)", "Bash(pac * help)",
      "Bash(pac auth list)", "Bash(pac auth who)",
      "Bash(pac solution list*)", "Bash(pac solution check*)",
      "Bash(dotnet --version)", "Bash(dotnet --list-sdks)",
      "Bash(git status*)",
      "Bash(pac pcf push*)", "Bash(pac solution import*)"
    ]
  }
}
```

**Deliberately left off:** `pac solution publish` and `pac auth create`.
Publish affects every customization in an environment, not just this
control, and always requires its own explicit confirmation regardless of
classification — allowlisting it here would remove the only thing still
protecting against an accidental environment-wide publish. Auth-profile
creation is a one-time setup action with no routine-friction benefit to
allowlisting.

## One-time design/manifest approval

**Gate A (React design) and Gate B (manifest) apply once per control —
the first time it's ever built.** The first time you build a new control,
you see the actual rendered UI and the full manifest proposal and type
approval for both, exactly as always. Once both are approved and recorded
for that control, **no later update reopens either gate** — not a bug
fix, not a styling change, not a new or changed manifest property, not a
new feature. The change is made, a short summary of what it actually did
is shown, and work continues straight through validation and deployment
with no "do you approve" question for design or manifest, ever again, for
that control.

**The one exception:** converting a standard control to a React control.
That's an architectural rewrite — a different base interface, a
rewritten `index.ts`, new platform-library entries — not an update, and
it always requires the full design and manifest approval again regardless
of the control's history.

**What's still shown, even though nothing blocks on it:** every update is
labeled honestly before it runs — a **defect correction** (the control
now finally does what was already approved; e.g. a broken localization
string or a data-fetch bug that left a required field blank) or a
**design change** (something new — a restyle, a new state, an interaction
nobody had approved yet). Styling/CSS changes default to the design-change
label. This labeling doesn't gate anything anymore; it's just honesty
about what shipped, and it's recorded in the control's spec file so a
later session — or you — can see what changed since the one approval on
record.

**The trade-off, stated plainly:** once a control has cleared its first
design and manifest review, nothing else stops a wrong or unwanted change
from shipping to a `development` environment before you see it — you'll
learn what happened from the pre-run summary and the post-deployment
report, not from a preview you approved in advance. Deployment to
`test`/`UAT`/`staging`/`production` is unaffected by any of this — Gate C
still requires its own explicit confirmation there regardless of what
Gate A/B's history looks like, so a genuinely wrong change still has a
backstop before it reaches a shared or production environment, even
though nobody reviewed the design or manifest change itself at that point.

## Preview failures are reported, not hidden

A preview that doesn't render is a failure the skill has to catch and tell
you about — not something you should have to discover and report yourself.

Every command in the preview stage has its exit status and output read, and
the page itself is checked (mount root non-empty, no console error, no
error overlay, screenshots looked at before they're shown). **If anything
fails — a non-zero exit, an error in the output, a blank page — you're told
immediately, with the exact error text and the one targeted change being
applied.** Then the same command and the same check are re-run, and you're
asked to reload and confirm:

> "Can you see the preview rendering correctly at `<url>` — every state
> visible, no blank page and no error overlay?"

That loop repeats until you confirm you can see it. Only then does Gate A's
approval question get asked, as a separate question — *can you see it*
first, *do you approve it* second, never merged into one. A design approval
given over a preview that never rendered isn't accepted as Gate A approval.

What this rules out: silently retrying a failing command and showing you
only the run that worked, handing over a `localhost` URL nobody checked,
reporting a partial success as success, or substituting a description of
the intended UI for a preview that didn't come up. The most common cause of
a blank preview — two React copies across the preview/PCF boundary,
producing React error #321 — is now prevented by the generated preview
config and diagnosed by
[troubleshooting.md § T28](skills/pcf-control-builder/references/troubleshooting.md#t28--preview-renders-blank--no-elements-on-the-page)
when it still shows up.

## Automatic deployment to development environments

**`development`-classified deployments never require a confirmation step
— not a readiness report, not a typed string, not even on the first
deployment to a brand-new environment.** Immediately before running, the
skill shows a one-line heads-up (operation, environment, version) and
runs the command; the full result — including any errors — is reported
afterward. This is true for every push/import to a `development` target,
first one or the hundredth, same conversation or a new one days later.

What's still asked, and why it isn't a confirmation step: the first time
a given environment is used for a project, its URL, and (depending on
method) the publisher prefix or managed/unmanaged choice, are genuinely
unknown — a wrong guess on any of these would be actively harmful, so
they're asked once, as information-gathering. That's the only thing
standing between "just push" and the command actually running for a
brand-new dev target; once those values are known (from that one ask, or
already on record from a prior deployment), nothing else is asked, ever,
for that target.

This does **not** apply to:
- `test`/`UAT`/`staging`/`production` — always the full confirmation flow,
  every time, with no exceptions, first deployment or the hundredth.
- `pac solution publish` — always its own, separately confirmed operation,
  for any classification including `development`, because it affects the
  whole environment rather than this one control.
- This section is only about the *deployment* confirmation step (Gate C).
  Gate A and Gate B (design/manifest approval) follow a separate,
  one-time-per-control policy instead — see
  [One-time design/manifest approval](#one-time-designmanifest-approval).

**The trade-off, stated plainly:** environment classification is
something you tell the skill, not something it can verify against
Dataverse. If an environment is ever misclassified as `development`,
there is no remaining checkpoint before code reaches it — not even a
first-deployment review. If you'd rather keep the confirmation step for a
specific dev environment anyway, just say so ("always confirm before
deploying to this one") — the skill records that as a per-environment
override and goes back to asking every time for that target.

## Example use cases

- **New field control** — a single bound column with a custom React UI
  (e.g., a color picker, a formatted URL launcher, a rating widget).
- **New dataset control** — a React grid or card view over a Dataverse
  dataset with sorting, filtering, and selection.
- **Modifying an existing control** — adding a property, changing a
  manifest type, fixing a bug, or restyling the UI, without breaking the
  existing scaffold. Once the control's design and manifest have been
  approved once, none of this re-triggers Gate A/B — see
  [One-time design/manifest approval](#one-time-designmanifest-approval).
- **Troubleshooting** — diagnosing build failures, manifest/type mismatches,
  or `pac` CLI errors using evidence (command output) rather than guesses.
- **Packaging and deployment** — creating or updating a solution project,
  versioning it, and pushing/importing it to a Dataverse environment behind
  an explicit, typed confirmation for `test`/`UAT`/`staging`/`production`,
  or automatically for `development` — see
  [Automatic deployment to development environments](#automatic-deployment-to-development-environments).

## Limitations and safety notes

- **No automatic installs.** The skill never installs or updates Node.js,
  npm, the Power Platform CLI, .NET, MSBuild, or Visual Studio — it reports
  what's missing and lets you install it.
- **No silent deployments to test/UAT/staging/production.** Nothing is
  pushed, imported, or published to one of those without a typed,
  single-use confirmation. "Publish it" or "ship this" alone never
  triggers a remote command there. **The one exception** is `development`,
  which deploys automatically without asking — including the first
  deployment to a brand-new dev environment — see
  [Automatic deployment to development environments](#automatic-deployment-to-development-environments).
  `pac solution publish` is never automatic, for any environment,
  including `development`.
- **Design/manifest review happens once per control, not once per
  change.** Gate A and Gate B ask for explicit approval the first time a
  control is built; a bug fix, restyle, or manifest change after that
  ships without asking again, for that control, forever, except for
  converting a standard control to React — see
  [One-time design/manifest approval](#one-time-designmanifest-approval).
- **No secrets in commands or files.** The skill never passes a password,
  client secret, or certificate password as a CLI argument, and refuses to
  write one into the control's persistent spec file.
- **Read-only inspection scripts.** The bundled PowerShell scripts
  (`scripts/`) only inspect and validate — they never install software or
  write to a Dataverse environment.
- **Not a replacement for review.** The skill reduces mistakes and shows
  what it did — the actual diff, a plain-language summary of each
  update, and a post-deployment report — but for a control that's already
  cleared its one-time design/manifest approval, that review happens
  after the fact, not as a blocking gate. Read those summaries; the skill
  won't wait for you to.

## Repository structure

```text
.claude-plugin/
  plugin.json              — plugin manifest
  marketplace.json         — self-hosted marketplace listing (this repo is both)
skills/pcf-control-builder/
  SKILL.md                 — the skill's core workflow, gates, and routing table
  references/              — detailed per-topic guidance, loaded on demand
  templates/                — the control-spec, manifest-proposal, and deployment-readiness templates
  examples/                 — worked transcripts
  scripts/                  — read-only PowerShell inspection/validation scripts
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for what changed in each version.

## Contributing

Issues and pull requests are welcome — see
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

Released under the [MIT License](LICENSE).

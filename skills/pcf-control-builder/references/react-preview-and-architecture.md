# React design preview and PCF integration architecture

## Table of contents
- [Part 1: Preview](#part-1-preview)
  - [Component construction rules](#component-construction-rules)
  - [Preview harness selection](#preview-harness-selection)
  - [Isolated preview workspace layout](#isolated-preview-workspace-layout)
  - [What the user is shown](#what-the-user-is-shown)
  - [Preview verification loop (before Gate A)](#preview-verification-loop-before-gate-a)
  - [What the preview stage must not do](#what-the-preview-stage-must-not-do)
  - [No-Node fallback](#no-node-fallback)
  - [Gate A mechanics](#gate-a-mechanics)
- [Part 2: Integration architecture](#part-2-integration-architecture)
  - [Follow the scaffold, not a fixed template](#follow-the-scaffold-not-a-fixed-template)
  - [React virtual controls](#react-virtual-controls)
  - [Standard controls](#standard-controls)
  - [Code-quality checklist](#code-quality-checklist)
  - [Dependency and generated-file policy](#dependency-and-generated-file-policy)

---

## Part 1: Preview

The user must see and approve the actual UI before any business-specific PCF
integration exists. The component they approve is the component that ships
— not a throwaway mock rebuilt later.

### Component construction rules

1. **Pure React component, fully typed props.** No `any` without an inline
   justification comment.
2. **Zero `ComponentFramework` coupling.** The presentational component does
   not import from `ComponentFramework`, does not accept `context`, does not
   read `context.parameters`. It receives plain values and plain callbacks.
3. **Scoped CSS in a separate file.** No inline style objects for anything
   that belongs in CSS, no CSS-in-JS. Class names carry a control-specific
   prefix (e.g. `.contoso-urllauncher__button`) so styles cannot leak into
   the host app.
4. **Mock data and mock callbacks** live in a preview-only module, clearly
   separated from component source.
5. **Every relevant state is rendered:** normal, empty, loading, error,
   disabled, read-only. If a state does not apply, record why in the spec
   §5.
6. **One source of truth.** The preview imports the same `.tsx` file that
   PCF will later import. Never duplicate the UI for preview purposes.

### Preview harness selection

Decide in this order:

| Order | Condition | Action |
|---|---|---|
| 1 | Repo already has Storybook | Add a story file for the component and its states. No new tooling. |
| 2 | Repo already has Vite / a dev server / an existing preview app | Add a preview route or entry importing the component. |
| 3 | Neither | Create an isolated minimal preview workspace (below). |

### Isolated preview workspace layout

```
<pcf-project-root>/
  <ControlName>/
    components/<ControlName>Component.tsx     <- the real component
    css/<ControlName>.css                     <- the real scoped CSS
    ControlManifest.Input.xml
    index.ts
  preview/                                    <- preview-only, never bundled
    package.json          (own deps: vite, react, react-dom, @types/*)
    vite.config.ts
    index.html
    main.tsx              (imports ../<ControlName>/components/...)
    mockData.ts
    README.md             (states this folder is preview-only)
```

Why a sibling folder with its **own** `package.json`: the PCF bundle entry
is `index.ts`, and pcf-scripts bundles only what that entry reaches. A
`preview/` folder never imported by `index.ts` cannot enter the control
bundle. Isolating its dependencies additionally keeps them out of the PCF
project's `package.json`, so nothing preview-related can influence
`npm ci`, peer resolution, or the shipped package.

**The boundary this layout creates has one mandatory consequence.** The
component lives *outside* the preview workspace but is imported *into* it,
so its own `react` / `react-dom` imports resolve from the PCF project's
`node_modules` while the preview entry resolves from
`preview/node_modules` — two React copies in one page. Every hook then
throws **React error #321, "invalid hook call"**, React unmounts the tree,
and the page renders with **no elements at all**. This is not an edge
case; it is the default outcome of this layout whenever the PCF project
has React installed. Deduplicate from the first version of the config,
not after the blank page appears:

```ts
// preview/vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    // The component is imported from outside preview/, so without these two
    // it resolves its own React from the PCF project's node_modules -> two
    // React instances -> React #321 (invalid hook call) -> blank page.
    dedupe: ['react', 'react-dom'],
    alias: {
      react: path.resolve(__dirname, 'node_modules/react'),
      'react-dom': path.resolve(__dirname, 'node_modules/react-dom'),
    },
  },
  // Serving a file above the Vite root is what this layout does by design.
  server: { fs: { allow: [path.resolve(__dirname, '..')] } },
});
```

Deduplicate only `react` and `react-dom` — the narrowest fix that resolves
the duplication. Do not add unrelated packages to `dedupe`, and do not
"solve" it by copying the component into `preview/` (that breaks the
one-source-of-truth rule) or by installing React into the preview folder
only (the component still resolves its own). `dedupe` covers `vite build`
as well as the dev server, so a preview that works in dev and breaks when
built means the config was applied to only one of them. Diagnosis for a
blank page is [troubleshooting.md § T28](troubleshooting.md#t28--preview-renders-blank--no-elements-on-the-page).

Required hygiene:
- Add `preview/node_modules/` and `preview/dist/` to `.gitignore`.
- Only exclude `preview/**` from the PCF `tsconfig.json` if the existing
  `include`/`exclude`/`extends` chain actually requires it — read the
  inheritance first (see [Dependency and generated-file policy](#dependency-and-generated-file-policy)).
  Do not add path prefixes speculatively.
- `preview/README.md` states the folder is preview-only and safe to delete.

### What the user is shown

1. The exact preview command and the local URL, e.g.
   `npm --prefix preview install` then `npm --prefix preview run dev` ->
   `http://localhost:5173` (verify the actual port from the dev-server
   output, don't assume the default).
2. The component source and the CSS source.
3. **A visual.** If a browser/screenshot capability is available in the
   session, capture one screenshot per state, look at each one before
   presenting it, and confirm it is not blank or an error overlay. If no
   such capability exists, say so explicitly and rely on the user opening
   the URL — never imply a screenshot was taken when only source code was
   produced.
4. An explicit list of **what is mocked**: which values are fake, which
   callbacks are no-ops, which behaviors only become real once PCF is wired.
5. **The result of the verification loop below** — either "these checks
   passed" naming them, or the failure and what is being done about it.
   Nothing in this list is presented as ready until that loop has run.

### Preview verification loop (before Gate A)

A preview is not delivered when the files are written or when a command is
launched. It is delivered when it has been **checked to render** and the
**user has confirmed they can see it**. Those are two separate obligations
and both are required.

The checks in §1 and the render-check question in §3 run **every time** — a
clean first run still ends with the user confirming they can see it,
because a check that passes in this session is not the same as a page that
renders on the user's machine. §2 and the fix/re-run cycle are what a
failure adds on top.

#### 1. Check every command and every signal

Never report, imply, or build on a successful preview without looking at
what the commands actually returned. Each round, check all of these that
apply:

| Source | Failure signal |
|---|---|
| `npm install` / `npm ci` in `preview/` | non-zero exit; `npm ERR!`; `ERESOLVE` |
| dev-server / `vite build` output | non-zero exit; `Failed to resolve import`; transform or TS errors; "Port NNNN is in use" (the URL you were about to quote is then wrong) |
| DOM / headless check, if available | mount root absent, empty, or whitespace-only; expected state sections missing |
| Browser console, if available | any `Uncaught`; any `react.dev/errors/<n>` code; failed module requests |
| Rendered page / screenshot | blank frame; Vite error overlay; a state that renders nothing |

A screenshot showing a blank frame or an error overlay is a **failure
signal, not a deliverable** — look at each capture before presenting it.
Absence of a check is not a pass: if no browser or screenshot capability
exists in the session, say that plainly rather than describing the page as
if it had been seen.

#### 2. Report the failure, immediately and in full

If anything above fired, the failure is the **first** thing in the next
message to the user — before the source listings, before the URL, before
any question. State:

- which command or check failed, and its **exact first error text**, quoted;
- what that means in one sentence;
- the single targeted change being applied (per
  [the evidence rule](troubleshooting.md#the-evidence-rule) — one cause,
  one fix, not a shotgun).

Banned: presenting a partial success as success; retrying a failing
command silently and showing only the run that worked; handing over a URL
that was never confirmed to render; describing what the UI "will look
like" in place of a preview that failed; downgrading to a hand-written
static HTML mock (see [No-Node fallback](#no-node-fallback) — the same
prohibition applies here).

#### 3. Fix, re-run, and ask the user to retry — then loop

1. *(failure path only)* Re-run **the same commands and the same checks**
   that failed, after applying the fix. Comparing against a different
   command proves nothing.
2. *(failure path only)* Report the new result honestly, including "still
   failing" when it is.
3. Ask the user to open or reload the page and answer, verbatim — **this
   step runs on a clean first run too, not only after a failure**:

   > "Can you see the preview rendering correctly at `<url>` — every state
   > visible, no blank page and no error overlay?"

4. **Only an explicit confirmation that they can see it advances the
   stage.** "ok", "sure", silence, a reply about something else, or
   approval of the design without answering this question do not count —
   re-ask, naming the ambiguity.
5. Anything else — "it's empty", "no elements", "there's an error", a
   pasted stack trace — restarts at step 1 with that new evidence. If the
   report is bare ("still nothing"), ask for the specific evidence needed:
   the browser console text, the dev-server output, or a screenshot.

The loop has **no iteration cap** — it runs until the user confirms. It is
still bound by the standard [escalation
rule](troubleshooting.md#escalation): once **two** targeted fixes have
failed, stop applying further fixes and report every hypothesis tried with
its result, what evidence is still missing, and which troubleshooting
branch this now falls under (usually
[T28](troubleshooting.md#t28--preview-renders-blank--no-elements-on-the-page)
or [T16](troubleshooting.md#t16--duplicate-reactfluent-bundling)). Guessing
past that point wastes the user's time and buries the real cause.

Each round is recorded in the spec §5 preview-verification log: the failure
signal, the cause identified, the fix applied, and the user's re-check
result.

#### 4. Keep the render check and Gate A separate

They are different questions asked in a fixed order, never merged into one
message:

| | Render check (this loop) | Gate A |
|---|---|---|
| Asks | *Does the preview work?* | *Is the design right?* |
| Answered by | the user seeing it render | the user approving what they saw |
| When | end of S4 | S5, after the render check is confirmed |

**Gate A is not asked while the render check is unconfirmed.** A design
approval given over a preview that never rendered — from reading the
source, or out of politeness — is not a valid Gate A approval: say the
preview hasn't been confirmed to render yet, run the render check, and ask
Gate A afterward. The single documented exception is the literal override
phrase in [Gate A mechanics](#gate-a-mechanics), which the user must state
themselves.

### What the preview stage must not do

No manifest business properties. No `feature-usage`. No `context.webAPI`.
No output wiring. No `notifyOutputChanged`. No solution project. No auth.
No deployment configuration.

### No-Node fallback

If Node.js/npm are unavailable (confirmed via
[`scripts/check-prerequisites.ps1`](../scripts/check-prerequisites.ps1)),
the preview stage cannot run. State this plainly. Offer to write the
component and CSS anyway so they are ready once Node is available. Record
`Gate A: blocked - no Node runtime` in the spec. **Never** substitute a
hand-written static HTML mock and present it as the approved design — that
produces a false Gate A approval that does not correspond to what will
actually render.

### Gate A mechanics

Full question wording, acceptance criteria, and override phrasing are in
[SKILL.md § The three gates](../SKILL.md#the-three-gates--verbatim) and
[workflow.md § S5](workflow.md#s5--gate-a-react-design-approval). Each
iteration appends to the spec §5 iteration log: what changed, why, and the
new screenshot paths.

Its precondition is the confirmed render check from the
[Preview verification loop](#preview-verification-loop-before-gate-a) — and
every change iteration goes back through that loop too. A UI change means a
re-run, a re-check, and a fresh confirmation that the user can still see it
before Gate A is re-asked; an edit that silently breaks the preview must
not turn into an approval request.

---

## Part 2: Integration architecture

### Follow the scaffold, not a fixed template

Read `index.ts` and the manifest to determine which architecture applies
(`control-type` as literally written — see
[`scripts/inspect-pcf-project.ps1`](../scripts/inspect-pcf-project.ps1)),
then apply the matching rule set below. Do not impose one shape on all
templates.

### React virtual controls

- Implement `ComponentFramework.ReactControl<IInputs, IOutputs>`.
- `updateView` **returns a React element**, as the generated template
  requires. It does not render into a container itself.
- `index.ts` is a thin **lifecycle and adapter layer**: read
  `context.parameters`, normalize values, build the props object, return
  the element. Business logic and presentation live in components and
  hooks.
- Pass **normalized values and typed callbacks** as props. Do not pass
  `context` into the component unless a specific, documented need exists —
  then pass the narrowest slice possible with a comment explaining why.
- `notifyOutputChanged` is called from **event handlers**, never from
  render, never from an effect that fires on every render. `getOutputs`
  returns the current committed values from a field the adapter owns.
- Implement `init`, `updateView`, `getOutputs`, `destroy` per the generated
  interface. `destroy` releases timers, aborts in-flight requests, removes
  listeners.
- **Stale-async handling:** every async operation carries a generation
  token or `AbortController`; results from a superseded call are discarded.
- **No WebAPI call on every `updateView`.** `updateView` fires often. Gate
  calls on an actual input change; cache or debounce.
- Respect `context.mode.isControlDisabled` and the bound property's
  read-only / field-security signals. Disabled and read-only are distinct
  states, both approved at Gate A.
- Localized strings come from `context.resources.getString(...)`, not
  string literals.
- Use supported PCF APIs (`context.navigation`, `context.utils`,
  `context.device`, `context.webAPI`) rather than `window.*` equivalents.

### Standard controls

Follow the standard-control lifecycle `pac` generated:
`init(context, notifyOutputChanged, state, container)` renders into
`container`; `updateView(context)` updates the DOM; `destroy()` cleans up.
**ReactControl rules do not apply.** Never introduce React into a standard
control without an explicit, separately-approved conversion decision — see
[manifest-design.md § Control metadata](manifest-design.md#control-metadata)
for why flipping `control-type` alone does not perform a real conversion.

### Code-quality checklist

Apply as a review pass before Gate B closes and again at S9:

- [ ] Typed React props; no implicit `any` without justification
- [ ] Separate scoped CSS; no CSS-in-JS
- [ ] Keyboard accessibility
- [ ] Appropriate ARIA attributes
- [ ] Deliberate focus behavior
- [ ] Responsive sizing
- [ ] High-contrast compatibility
- [ ] Localization via `context.resources`
- [ ] Loading / empty / error / disabled / read-only states implemented
- [ ] Safe URL handling (scheme allow-list; never render an unvalidated `javascript:` URL)
- [ ] No `dangerouslySetInnerHTML` on unsanitized content
- [ ] No embedded credentials, no secrets in client-side code
- [ ] No unnecessary dependencies
- [ ] No duplicated React tree (see the `platform-library` rules in [manifest-design.md](manifest-design.md#resources-section))
- [ ] No avoidable render loops
- [ ] No WebAPI calls during render
- [ ] Graceful failure handling
- [ ] Clean destroy/unmount
- [ ] Comments only where they explain a non-obvious decision

**Fluent UI:** use it when it improves host consistency and is compatible
with the platform-library setup in the manifest. Not required for every
control. Adding it must not create a duplicate Fluent bundle.

### Dependency and generated-file policy

- Preserve the versions the current `pac` template generated unless a
  **verified** problem requires a change. "A newer version is available" is
  not a verified problem.
- Inspect `package.json`, `package-lock.json`, and actual `npm` output
  before changing any package.
- Never replace `package.json` wholesale.
- `npm ci` when the lockfile is valid and a clean reproducible install is
  wanted; `npm install` only when intentionally changing dependencies.
- Never assume `@typescript-eslint/parser` must share a major version with
  ESLint — read the peer requirement from the actual error output.
- Never blindly create `.eslintrc.json`. Detect first: legacy `.eslintrc*`,
  flat `eslint.config.*`, pcf-scripts-provided linting, or no lint script at
  all ([`scripts/inspect-pcf-project.ps1`](../scripts/inspect-pcf-project.ps1)
  reports which). Match what exists.
- Inspect `tsconfig.json` **inheritance** (`extends`) and the real folder
  layout before touching `include`/`exclude`. Do not add project-folder
  prefixes unless the actual structure requires them.
- Run `npm run refreshTypes` after manifest changes — only if that script
  exists.
- Read generated `ManifestTypes.d.ts` before concluding a type is missing.
  Never hand-edit it; regenerate.

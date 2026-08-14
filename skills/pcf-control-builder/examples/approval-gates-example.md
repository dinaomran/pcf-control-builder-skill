# Approval-gate handling: correct vs incorrect

Short transcripts illustrating the gate rules in
[SKILL.md § The three gates](../SKILL.md#the-three-gates--verbatim). All
values are placeholders.

---

### [WRONG] Treating "looks good" as approval

> **User:** looks good
>
> **Skill (wrong):** Great, moving on to the manifest workshop...

This is wrong. "Looks good" was not a reply to the exact Gate A question,
and could mean "the screenshot rendered" rather than "I approve this
design." The correct response re-asks, naming the ambiguity:

> **Skill (correct):** To make sure I record this correctly: do you approve
> this React design for manifest design and PCF integration, or should I
> change the UI or behavior first?

---

### [CORRECT] Explicit override of Gate A

> **User:** Skip the React preview approval gate.
>
> **Skill:** Understood — recording the override. Gate A: overridden
> 2026-08-10 — "Skip the React preview approval gate." Gate B (manifest
> approval) and Gate C (deployment confirmation) are still required before
> anything is integrated or deployed. Moving to the manifest workshop.

The override phrase is recorded **verbatim** in `docs/pcf/<control>-spec.md`
§18, and only Gate A is skipped — Gates B and C are untouched.

---

### [WRONG] Asking Gate A over a preview nobody checked

> **Skill (wrong):** Preview is running at http://localhost:5173. Do you
> approve this React design for manifest design and PCF integration, or
> should I change the UI or behavior first?
>
> **User:** the page is empty, there are no elements

Wrong before the user ever replied. The commands exited 0, but nothing
checked that the page actually rendered, and the gate question was asked
over an unverified preview — so the user ended up doing the skill's
verification for it. Correct handling runs the
[verification loop](../references/react-preview-and-architecture.md#preview-verification-loop-before-gate-a)
first and reports the failure itself:

> **Skill (correct):** Preview built, but it does not render — before
> anything else: my DOM check on the built page found the mount root empty,
> and the console shows `Uncaught Error: Minified React error #321`
> (invalid hook call). Cause: the bundle contains two React instances,
> because `preview/` and the component sit on opposite sides of the
> isolated-workspace boundary and resolve different copies. Applying the
> narrow fix — deduplicating only `react` and `react-dom` in
> `preview/vite.config.ts` — then re-running the same DOM check and preview
> build.
>
> *(applies the fix, re-runs the same build and the same check)*
>
> Re-checked: build exits 0, the root now renders all six state sections,
> console clean. Can you see the preview rendering correctly at
> http://localhost:5173 — every state visible, no blank page and no error
> overlay?
>
> **User:** yes, all six show up now
>
> **Skill:** Do you approve this React design for manifest design and PCF
> integration, or should I change the UI or behavior first?

Two questions, in order, in separate messages: *can you see it* — then *do
you approve it*. The failed round is logged in spec §5's
preview-verification log. Diagnosis detail:
[troubleshooting.md § T28](../references/troubleshooting.md#t28--preview-renders-blank--no-elements-on-the-page).

---

### [WRONG] Retrying quietly and reporting only the run that worked

> **Skill (wrong):** *(`npm --prefix preview run build` fails; skill
> re-runs it after a change, it passes)* Preview is ready at
> http://localhost:5173 — all six states render.

Wrong even though the end state is fine: the user was never told the build
failed, what the error was, or what changed to fix it. If the same fault
resurfaces later — in the PCF build, where the same duplicate React breaks
the shipped control — there is no record it ever happened.

> **Skill (correct):** First build failed: `Failed to resolve import
> "react" from "../ContosoUrlLauncher/components/…"`. Fixed by adding the
> react/react-dom dedupe + alias block to `preview/vite.config.ts`, re-ran
> the same command, exits 0 now. Can you see the preview rendering
> correctly at http://localhost:5173 — every state visible, no blank page
> and no error overlay?

---

### [WRONG] Accepting "ok" as the render confirmation

> **Skill:** Can you see the preview rendering correctly at
> http://localhost:5173 — every state visible, no blank page and no error
> overlay?
>
> **User:** ok
>
> **Skill (wrong):** Great — do you approve this React design for manifest
> design and PCF integration?

"ok" may mean "understood, I'll look" as easily as "yes, I see it." Same
rule as the Gate A ambiguity above — re-ask, naming it:

> **Skill (correct):** Just to be sure before I ask you to approve
> anything: were you able to open the page and see the states rendering, or
> is it still blank on your side?

---

### [WRONG] "Just deploy it" skipping straight to a remote write

> **User:** just deploy it
>
> **Skill (wrong):** Running `pac solution import --path ... --environment ...`

Wrong on two counts: it assumes a target environment that was never
confirmed, and it skips every unmet gate. Correct handling enters at S10
and reports what's outstanding:

> **Skill (correct):** Entering deployment preparation. Before I can build
> a readiness report, these are still open: Gate A (React design) has not
> been approved, Gate B (manifest) has not been approved, and no target
> environment has been specified. Would you like to complete the design and
> manifest workshop first, or is there an already-approved spec I should be
> reading from `docs/pcf/`?

---

### [WRONG] "Just push" treated as full authorization, no matter the target

> **User:** just push
>
> **Skill (wrong):** Running `pac pcf push --environment https://contoso-prod.crm.dynamics.com ...`

Wrong — "push" named the tool, not the target, and isn't authorization to
use a dev-only tool against production. Correct handling still resolves the
environment first, and once it turns out to be production-classified, still
applies the stronger guard:

> **Skill (correct):** Which environment should I push to? *(Worksheet W8:
> URL/ID, classification, auth profile.)*
>
> *(user gives a URL that resolves to a production-classified environment)*
>
> **Skill:** That environment is classified production. `pac pcf push` is
> meant for the development inner-loop, not the default production
> deployment method — I'd recommend the package + `pac solution import`
> path instead. If you want push anyway, I need:
> `CONFIRM PRODUCTION IMPORT <target-identifier> <version> TO <environment-url>`.

---

### [CORRECT] "Just push" against a dev target, first time — no Gate C even now

> **User:** just push
>
> **Skill:** Which environment? *(W8: URL and classification — genuinely
> unknown, asked once; classification comes back `development`.)* *(W7
> push shape: publisher prefix — also genuinely unknown, asked once.)*
> *(Neither of those is a confirmation to deploy — they're the minimum
> information needed to build the command at all.)* Pushing
> ContosoUrlLauncher v1.0.0 to `https://contoso-dev.crm4.dynamics.com`
> (development, no confirmation required)...
>
> *(runs `pac pcf push` immediately — no readiness report, no typed
> `DEPLOY ...` string, not even on this first deployment — then reports
> the real result)*

Naming the tool directly skipped the method-*suggestion* step — the skill
didn't need to propose push vs. package, since the user already said
which one. Classification coming back `development` skipped Gate C
entirely, per
[deployment-and-alm.md § Development deployments run without a
confirmation gate](../references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate)
— this is true even though it's the first time this environment has been
used for this project. Only the genuinely-unknown values (URL, publisher
prefix) were asked, once, as information-gathering — not as approval.

---

### [CORRECT] "Push again" against the same dev target — even less is asked

> **User:** *(having pushed to `https://contoso-dev.crm4.dynamics.com`
> earlier — this session or a prior one)* fixed the bug, push again
>
> **Skill:** Pushing ContosoUrlLauncher v1.0.2 to
> `https://contoso-dev.crm4.dynamics.com` (development, no confirmation
> required)...
>
> *(runs `pac pcf push`, then reports the real result: exit status,
> warnings if any, updated spec §19 deployment-history row)*

No Worksheet W8, no Worksheet W7 either this time — the URL and publisher
prefix are already on record in spec §17/§16, so even the one-time
information-gathering from the previous example doesn't happen again.
This is the **one** documented exception to "no remote write without Gate
C" — it never extends to `test`/`UAT`/`staging`/`production`, and never
to `pac solution publish` even for this same dev target.

---

### [CORRECT] A brand-new control still requires Gate A/B — first build only

> **User:** build me a PCF field control that launches a URL
>
> *(S1-S4 run: requirement discovery, prerequisites, scaffold, React
> design + preview)*
>
> **Skill:** Do you approve this React design for manifest design and PCF
> integration, or should I change the UI or behavior first?
>
> **User:** approved
>
> *(S6 manifest workshop runs)*
>
> **Skill:** Do you approve this manifest proposal for PCF integration?
>
> **User:** approved

This is the **only** point in a control's life where Gate A and Gate B
ask anything, per
[workflow.md § Gate A/B: one-time approval](../references/workflow.md#gate-ab-one-time-approval-not-per-change).
Both approvals are recorded in spec §18 with today's date. From this
point on, for this control, neither question is asked again — see the
next example.

---

### [CORRECT] Any later update — bug fix or design change alike — skips Gate A/B entirely

> **User:** redeploy — this fixes the Arabic UI-text bug (switched to
> code-based EN_STRINGS/AR_STRINGS selection) and the `$expand`
> navigation-property fix for category/sub-category

> **Skill:** Fixed — Arabic string selection now runs from
> `EN_STRINGS`/`AR_STRINGS` based on language (defect correction — spec
> §7 already required Arabic), and the WebAPI call now `$expand`s
> category/sub-category so they're no longer blank (defect correction —
> spec §10 already required them). Running validation, then pushing to
> `<dev-url>` (development, no confirmation required)...

> **User:** *(later)* now tighten the spacing between the
> category/sub-category rows and switch the accent color to the new brand
> blue

> **Skill:** Updated — tightened row spacing and changed the accent color
> to `#1a73e8` (design change — neither was in spec §5, this is new).
> Running validation, then pushing to `<dev-url>` (development, no
> confirmation required)...

Gate A and Gate B were approved once, back when this control was first
built (previous example). Per
[workflow.md § Gate A/B: one-time approval](../references/workflow.md#gate-ab-one-time-approval-not-per-change),
**neither request reopens either gate** — not the bug fix, and not the
styling change, even though the styling change is unambiguously a new
design decision nobody explicitly approved yet. What's different between
the two replies is only the **label** — "defect correction" naming the
spec section it restores, "design change" naming what's new — per
[workflow.md § Labeling a change](../references/workflow.md#labeling-a-change-defect-correction-vs-design-change).
That label is honesty about what shipped, not a gate; both replies run
straight through to deployment with no question and no wait.

---

### [CORRECT] Converting a standard control to React is the one exception — always fully re-gated

> **User:** convert this control to use React instead of the standard
> lifecycle

> **Skill:** This is an architectural rewrite, not an update — a
> different base interface, a rewritten `index.ts`, new
> `platform-library` entries, a different bundling model — and it's
> gated in full regardless of this control's prior approvals. Restarting
> at S3 for an explicit scope decision, then S4 (design), S6 (manifest),
> and S10 (deployment) each require their normal approval again.

The one-time-approval policy above explicitly excludes this case — see
[workflow.md § existing-project change map](../references/workflow.md#existing-project-change-map).
Every other row in that table skips Gate A/B once a control has been
through them; this one never does.

---

### [WRONG] Accepting "yes" for a production confirmation

> **Skill:** ... type exactly: `CONFIRM PRODUCTION IMPORT
> ContosoUrlControls 1.0.0.3 TO https://contoso-prod.crm.dynamics.com`
>
> **User:** yes
>
> **Skill (wrong):** Confirmed — running `pac solution import`...

Wrong — "yes" is explicitly excluded. Correct handling re-displays the
required string and waits:

> **Skill (correct):** That confirmation requires the exact string below —
> "yes" isn't accepted for a production import. Please type:
> `CONFIRM PRODUCTION IMPORT ContosoUrlControls 1.0.0.3 TO
> https://contoso-prod.crm.dynamics.com`

---

### [CORRECT] Artifact changes after Gate C confirmation

Applies only to `test`/`UAT`/`staging`/`production`, where a Gate C
confirmation actually exists to be voided. `development` never has a Gate
C confirmation to void — see the note below.

> **User:** *(after confirming a production import)* actually wait, let
> me fix one more thing in the component first
>
> **Skill:** Understood — no import has run yet. Once you've made the
> change and we rebuild, the earlier confirmation is void because the
> artifact changed; I'll regenerate the readiness report with the new
> build's timestamp and size, and ask for a fresh
> `CONFIRM PRODUCTION IMPORT ...` confirmation before anything runs.

For a `development` target, there's no pending confirmation for a
mid-flight change to void in the first place — the heads-up line and the
push happen together, with nothing waiting in between, on the first
deployment or any later one. A change made *after* a push already ran
just becomes a new request: re-enter at S8, rebuild, and the next push
(still gate-free) picks up the new code and the next version number.

---

### [CORRECT] Authenticated environment does not match the requested target

> **Skill:** `pac auth who` shows profile "dev-eu" resolving to
> `https://contoso-dev.crm4.dynamics.com`, but you asked to deploy to
> `https://contoso-test.crm4.dynamics.com`. These don't match, so I'm
> stopping here. `pac auth list` shows a profile named "test-eu" that
> already points at the test environment — should I select that, or do you
> want to create a new profile?

No push/import command runs until the mismatch is resolved and re-verified
with a fresh `pac auth who`.

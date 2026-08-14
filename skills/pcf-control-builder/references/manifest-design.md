# Manifest design workshop

## Table of contents
- [Order of operations](#order-of-operations)
- [Control metadata](#control-metadata)
- [Property proposal table](#property-proposal-table)
- [Type groups](#type-groups)
- [Dataset controls](#dataset-controls)
- [Feature usage](#feature-usage)
- [External services](#external-services)
- [Events and property dependencies](#events-and-property-dependencies)
- [Resources section](#resources-section)
- [Gate B package](#gate-b-package)

## Order of operations

1. Confirm the **target host** first — manifest element availability
   differs across model-driven apps, canvas apps, and custom pages.
2. **Read** the current `ControlManifest.Input.xml` in full (or use
   [`scripts/inspect-pcf-project.ps1`](../scripts/inspect-pcf-project.ps1)).
3. Propose changes as a diff against what is actually there.
4. Never edit before Gate B closes.

## Control metadata

Propose and justify each attribute: `namespace`, `constructor`, `version`,
`display-name-key`, `description-key`, `control-type`, plus any other
attribute the generated scaffold or current schema requires.

**Hard rules:**

- For a React scaffold, **preserve the virtual-control architecture** the
  scaffold generated. Read `control-type` from the file; never assume its
  value.
- **Never convert a standard control to a React control by editing
  `control-type`.** That change alone produces a control that fails at
  runtime: the standard scaffold implements `StandardControl` with DOM
  rendering into a container, while a virtual control must implement
  `ReactControl` and return an element from `updateView`. A genuine
  conversion means rewriting `index.ts`, changing the base interface,
  adding React `platform-library` entries, and adjusting the bundle — treat
  this as a separate decision the user must explicitly make, not a
  side-effect of a manifest edit.
- `version` follows the control-version policy recorded in the spec §16;
  bumping it invalidates Gate C.

## Property proposal table

For every proposed property, present a row with **all** of:

| Field | Notes |
|---|---|
| `name` | camelCase, descriptive. Never `myFirstProperty`, `sampleProperty`, `property1` except when literally explaining this rule with a generic example. |
| Business purpose | One line, in the user's domain language. |
| `display-name-key` | Must exist in the proposed RESX. |
| Display text | The RESX value. |
| `description-key` | Must exist in the proposed RESX. |
| Description text | The RESX value. |
| `of-type` / `of-type-group` | Only types valid for the selected host and current schema — verify per [official-source-policy.md](official-source-policy.md#where-to-verify-hosttypeelement-support). |
| `usage` | `bound` / `input` / `output`, explained for the selected host. |
| `required` | With justification. |
| `default-value` / `pfx-default-value` | Only when supported for that type/host and genuinely useful. |
| React prop mapping | `props.<name>` |
| `context.parameters` mapping | `context.parameters.<name>.raw` / `.formatted` / etc. — state which accessor. |
| `getOutputs` mapping | Field name in `IOutputs`, or "n/a (input only)". |
| Validation rules | What the component enforces and what happens on invalid input. |

Illustrative shape only — real values come from the approved requirement:

```xml
<property
  name="urlValue"
  display-name-key="urlValue_Display_Key"
  description-key="urlValue_Desc_Key"
  of-type="SingleLine.URL"
  usage="bound"
  required="true" />
```

Suggest every field and explain each suggestion. Ask the user to approve or
edit per row (`edit P2: required=false`). Never force manual entry of an
attribute that can be reliably inferred.

## Type groups

Use `type-group` + `of-type-group` **only** when a property legitimately
accepts several compatible Dataverse types (e.g. a numeric display control
accepting `Whole.None`, `Decimal`, `FP`, `Currency`). When one type
suffices, use `of-type`. State which case applies and why — a type group
chosen "for flexibility" with no concrete multi-type need is unjustified
and must not be proposed.

## Dataset controls

When the template is `dataset`, model the requirement with the correct
schema constructs — never as a bag of field properties:

- `data-set` — primary dataset; additional `data-set` elements for
  secondary datasets when the host supports them.
- `property-set` inside `data-set` — the per-column bindings the maker
  configures.
- `cds-data-set-options` — where supported by host and schema.
- Selected columns, sorting, filtering, paging, selection behavior — each
  recorded in the spec §10 with the API the component will use.
- Loading and empty states — must correspond to the states approved at Gate
  A.
- Dataset refresh behavior — who triggers `refresh()`, and the guard
  preventing refresh loops (never call it unconditionally from
  `updateView`).

## Feature usage

Derive from **actual code requirements**, never from a checklist.

```xml
<feature-usage>
  <uses-feature name="WebAPI" required="true" />
</feature-usage>
```

Rules:

- Confirm `feature-usage` is supported for the selected host before
  proposing it.
- Add `WebAPI` **only** if the implementation calls `context.webAPI`.
- Add `Utility` / `Device.*` features **only** if the corresponding PCF
  APIs are used.
- Use exact feature names from the current schema — verify against current
  official documentation rather than reciting from memory.
- Explain why each feature is needed.
- Explain `required="true"` (host must provide it; control fails without
  it) vs `required="false"` (optional; **the code must check availability
  at runtime and degrade gracefully**). A `required="false"` declaration
  with no fallback path in the code is a defect — do not ship it.
- **Omit the entire `<feature-usage>` block** when nothing is required. An
  empty block is not the neutral choice.
- An external HTTP service is **not** Dataverse WebAPI. Declaring `WebAPI`
  for a `fetch()` to a third-party API is wrong — see
  [External services](#external-services).

## External services

When the control calls a non-Dataverse service, assess and record: whether
`external-service-usage` is required for the target host; the exact domain
entries; host support; licensing implications (external-service usage can
affect licensing/certification posture); CORS and authentication approach;
and whether any secret would end up in client-side code.

**Absolute rule:** no secret goes into PCF source, the manifest, CSS, RESX,
the spec file, or any file the skill writes. If the design requires a
secret, the answer is a server-side intermediary (Power Automate, a custom
connector, an Azure Function) — say so and do not proceed with an embedded
key.

## Events and property dependencies

Assess current schema capabilities (events, property dependencies,
host-specific elements) only when the requirement calls for them. Verify
against current official documentation for the target host. Do **not** add
them speculatively.

## Resources section

Propose the complete `<resources>` block as a table:

| Type | Path | Order/Version | Exists? | Action | Why required | Host availability |
|---|---|---|---|---|---|---|

```xml
<resources>
  <code path="index.ts" order="1" />
  <css path="css/<ControlName>.css" order="1" />
  <resx path="strings/<ControlName>.1033.resx" version="1.0.0" />
</resources>
```

Rules:

- Keep exactly the `code` entry the scaffold generated.
- CSS stays in `.css` files, outside `.ts`/`.tsx`, scoped to the control.
- **Validate every referenced path against the filesystem** (or use
  [`scripts/validate-pcf-project.ps1`](../scripts/validate-pcf-project.ps1)).
  A `css` path that does not exist is a build failure to catch here, not at
  build time.
- **Validate every localization key against RESX content, in both
  directions**: every manifest key exists in RESX, and unused RESX keys are
  reported.
- Add `img` only for a genuinely required image resource.
- Add `dependency` only for a real component-library dependency.
- For a React scaffold: **read and preserve** the generated
  `platform-library` entries. Never hard-code versions; never add or remove
  them casually.
- Never bundle React or Fluent when the platform library already supplies
  them — that produces a duplicate React tree at runtime.
- If Fluent is genuinely unused, evaluate removing the generated Fluent
  `platform-library` entry, and state the trade-off before doing so.
- Never add `platform-library` elements to standard (non-virtual) controls.

## Gate B package

Before any manifest edit, present all eleven items (use
[`templates/manifest-proposal.md`](../templates/manifest-proposal.md) as the
fixed layout):

1. Complete proposed manifest XML, or an exact diff against the current file.
2. Property table.
3. Dataset / property-set configuration.
4. Type groups.
5. Feature usage with justifications.
6. External-service usage.
7. Resources table.
8. React prop <-> PCF parameter <-> `getOutputs` mapping.
9. Files that will be created or changed.
10. The required generated-type refresh (`npm run refreshTypes`, if that
    script exists).
11. Host compatibility warnings — anything proposed that a *different* host
    would reject, flagged for future portability.

Then ask exactly: **"Do you approve this manifest proposal for PCF
integration?"** Record approval verbatim in the spec §9-§14. See
[SKILL.md § The three gates](../SKILL.md#the-three-gates--verbatim) for the
full acceptance rules.

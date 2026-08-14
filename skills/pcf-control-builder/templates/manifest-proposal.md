<!--
TEMPLATE: the Gate B package.

Applies once per control -- the first time its manifest is built. Fill
this out completely and present it to the user before that first manifest
edit; every section must be present, even when the answer is "not
applicable" -- an omitted section reads as an oversight, not a decision.
See references/manifest-design.md for the rules behind each section.

For a manifest change on a control that has ALREADY had Gate B approved
once, this template's blocking "Do you approve...?" question at the
bottom does NOT apply -- see
references/workflow.md#gate-ab-one-time-approval-not-per-change. The
property table / resources / XML-diff sections above are still useful as
a non-blocking summary of what changed (labeled per
references/workflow.md#labeling-a-change-defect-correction-vs-design-change),
shown before the change is applied, but nothing waits for a reply.
-->

# Manifest proposal: <ControlName>

## 1. Target host, template, control type

- Target host: `<model-driven app | canvas app | custom page | other>`
- Template: `<field | dataset>`
- Control type (read from `ControlManifest.Input.xml`, not assumed): `<standard | virtual>`

## 2. Control metadata

| Attribute | Current value | Proposed value | Why |
|---|---|---|---|
| namespace | | | |
| constructor | | | |
| version | | | |
| display-name-key | | | |
| description-key | | | |
| control-type | | *(unchanged unless a separate conversion decision was made)* | |

## 3. Property table

| ID | name | Business purpose | display-name-key | Display text | description-key | Description text | of-type / of-type-group | usage | required | default | React prop | context.parameters | getOutputs | Validation |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P1 | | | | | | | | | | | | | | |

## 4. Dataset / property-set configuration

Applicable: `yes | no -- field template`

<!-- If yes: -->

| data-set | property-set name | of-type | Sortable | Filterable |
|---|---|---|---|---|

Paging: <!-- fill -->
Selection behavior: <!-- fill -->
Loading/empty states: <!-- match Gate A approved states -->
Refresh trigger + guard: <!-- fill -->

## 5. Type groups

Applicable: `yes | no`

<!-- If yes, one row per group, with a non-empty justification: -->

| type-group name | Member types | Justification (must be non-empty) |
|---|---|---|

## 6. Feature usage

`<feature-usage>` block: `included | omitted -- nothing required`

| Feature | required | Justification (actual code behavior) | Fallback if `required="false"` |
|---|---|---|---|

## 7. External-service usage

Applicable: `yes | no`

- Domain(s): <!-- fill -->
- Host support: <!-- fill -->
- Licensing note: <!-- fill -->
- CORS / auth approach: <!-- fill -->
- Secret exposure assessment: <!-- must state explicitly that no secret is embedded -->

## 8. Resources

| Type | Path | Order/Version | Exists? | Action | Why required | Host availability |
|---|---|---|---|---|---|---|

Platform-library entries (React scaffolds -- preserved, not invented):

| name | version (read from manifest, not hard-coded) | Still needed? |
|---|---|---|

## 9. React prop <-> PCF parameter <-> output mapping

| React prop | context.parameters.\<x\>.\<accessor\> | IOutputs field |
|---|---|---|

## 10. Files to be created or changed

<!-- list -->

## 11. Generated-type refresh required

`yes -- npm run refreshTypes | no`

## 12. Host compatibility warnings

<!-- Anything proposed here that a DIFFERENT host would reject. Empty is a
     valid answer -- state "none identified" rather than omitting the section. -->

## 13. Complete proposed manifest XML (or exact diff)

```xml
<!-- paste here -->
```

---

**Do you approve this manifest proposal for PCF integration?**

Reply with:
```
approve all
edit P2: <field>=<value>      (any number of edit lines, by row ID)
reject
back
```

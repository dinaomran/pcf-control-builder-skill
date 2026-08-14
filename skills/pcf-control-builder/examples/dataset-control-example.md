# Worked example: dataset control with property-set

Same arc as [field-control-example.md](field-control-example.md); this
file only covers what differs for a `dataset` template control. All values
are placeholders.

## S3: scaffold

```powershell
pac pcf init --namespace <Namespace> --name <ControlName> --template dataset --framework react --outputDirectory "<path>" --run-npm-install
```

## S4: React design + preview

Same construction rules apply, with dataset-shaped mock data: an array of
mock records plus mock column definitions, so the preview can show a
populated grid, an empty-dataset state, and a loading state without any
real dataset binding. The component still takes typed props only — no
`ComponentFramework` dataset object passed into the presentational
component.

## S6: manifest proposal — the part that differs

Worksheet W5 (dataset-specific) instead of a flat property list. The
requirement here ("show related records with inline status") is modeled
as a `data-set`, **not** as individual bound properties — see
[manifest-design.md § Dataset controls](../references/manifest-design.md#dataset-controls)
for why a `property-set` is the correct construct once a control's data
scales beyond a fixed number of fields.

```xml
<data-set name="records" display-name-key="records_Display_Key">
  <property-set name="statusColumn" display-name-key="statusColumn_Display_Key" of-type="OptionSet" />
  <property-set name="labelColumn" display-name-key="labelColumn_Display_Key" of-type="SingleLine.Text" />
</data-set>
```

Decisions recorded in spec §10:
- Selected columns: `statusColumn`, `labelColumn` (maker-configurable via
  the property-set, not hard-coded).
- Sorting: enabled on `labelColumn`.
- Filtering: host-provided (no custom filter UI in this control).
- Paging: delegated to the dataset's built-in paging.
- Selection behavior: single-select, surfaced via an output property.
- Loading/empty states: match the Gate A approved states exactly.
- Refresh trigger: a manual "Refresh" button in the UI calls
  `context.parameters.records.refresh()` — **never** called unconditionally
  inside `updateView`, to avoid a refresh loop (see
  [react-preview-and-architecture.md § React virtual controls](../references/react-preview-and-architecture.md#react-virtual-controls)).

Feature usage: still omitted here unless the design also calls
`context.webAPI` for something beyond the bound dataset — a dataset control
does not automatically need `feature-usage` just because it's a dataset.

## S8: integration — the part that differs

`index.ts` reads `context.parameters.records` (a
`ComponentFramework.PropertyTypes.DataSet`), maps `records.sortedRecordIds`
to a plain array of typed row objects, and passes that array — not the
dataset object itself — as a prop. The refresh-loop guard lives in the
adapter: the "Refresh" callback passed to the component is the only thing
that calls `records.refresh()`.

## S9-S13

Identical shape to
[field-control-example.md](field-control-example.md#s9-validation) through
[verification](field-control-example.md#s13-verification); no
dataset-specific deviation in build, packaging, or deployment beyond what's
already covered there.

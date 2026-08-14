# Contributing

Thanks for considering a contribution to PCF Control Builder.

## Reporting issues

Open a GitHub issue with:

- What you asked the skill to do.
- What you expected vs. what happened.
- Your PAC CLI version (`pac --version`) and whether you're on Node.js/npm,
  if relevant.
- Any error output. Please redact environment URLs, tenant IDs, or other
  values you don't want public.

## Proposing changes

1. Fork the repository and create a branch for your change.
2. Keep changes scoped to the skill's content
   (`skills/pcf-control-builder/`) or its plugin/marketplace manifests
   (`.claude-plugin/`) — avoid mixing unrelated changes in one pull request.
3. Follow the conventions already in the skill:
   - No hard-coded versions, environment URLs, publisher prefixes, or
     other environment-specific values — use `<angle-bracket-placeholders>`.
   - Reference files (`references/*.md`) are loaded on demand; keep
     `SKILL.md` itself concise and route detail into the appropriate
     reference file.
   - PowerShell scripts under `scripts/` must remain read-only: no
     installation, authentication, or writes to a Dataverse environment.
4. If you're changing workflow behavior (stages, gates, or safety rules),
   update the relevant example transcript under `examples/` to match.
5. Open a pull request describing what changed and why.

## Questions

Open an issue if anything about the workflow, gates, or a specific
reference file is unclear — clarifying the docs helps everyone using the
skill.

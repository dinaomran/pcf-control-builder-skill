# Official source policy

## Table of contents
- [Source priority](#source-priority)
- [How to query the PAC CLI correctly](#how-to-query-the-pac-cli-correctly)
- [When installed CLI conflicts with this skill](#when-installed-cli-conflicts-with-this-skill)
- [No hard-coded versions, ever](#no-hard-coded-versions-ever)
- [Where to verify host/type/element support](#where-to-verify-hosttypeelement-support)
- [Dated CLI snapshot — re-verify before relying on it](#dated-cli-snapshot--re-verify-before-relying-on-it)
- [Recording a new deviation](#recording-a-new-deviation)

## Source priority

When any technical claim is needed — a CLI flag, a manifest element, a supported type, a build command — resolve it in this order and stop at the first source that answers the question:

1. **Existing project files.** The generated scaffold, `ControlManifest.Input.xml`, `package.json`, `*.cdsproj`, `*.pcfproj` are ground truth for *this* project. Read them before proposing anything that touches them.
2. **Installed CLI help**, run on the user's machine. `pac <group> <verb> help` for PAC CLI syntax. Command-line help reflects the CLI version actually installed, which may differ from any documentation or memory.
3. **Current official Microsoft documentation** (Power Platform / PCF / Dataverse docs at learn.microsoft.com) — for concepts, schema elements, and host-support matrices not resolvable from #1 or #2.
4. **Current official Claude Code skills documentation** — only for questions about the skill format itself (frontmatter fields, discovery behavior), never for PCF/Dataverse technical content.
5. **General knowledge** — only when none of the above answers the question, and only with an explicit note that the claim is unverified.

Never use blog posts, forum answers, or "commonly copied" command snippets as a source, even if they match general knowledge — they are how stale syntax spreads.

## How to query the PAC CLI correctly

**`--help` is not a valid PAC CLI argument.** On this CLI, `pac <group> <verb> --help` prints `Error: An unknown argument --help was passed.` (it still prints usage text below the error, but do not rely on that; the intended form is different and cleaner).

**Correct form:**

```powershell
pac pcf init help
pac pcf push help
pac solution import help
pac auth create help
```

And for the verb list of a group:

```powershell
pac pcf help
pac solution help
```

Note for anyone piping this output: `pac <verb> help` exits `0` and prints full usage text. If you pipe it through something like `Select-Object -First 3` in PowerShell, `$LASTEXITCODE` can come back non-zero as an artifact of the truncated pipeline closing the native command's stdout early — that is a PowerShell piping effect, not a CLI failure. Capture full output before judging success.

**`pac --version` has the same trap as `--help`, in reverse.** On this CLI, `pac --version` prints the version banner (`Version: 1.37.4+g82c3669`) *and then* `Error: Not a valid command. Try running 'pac [command] help'.` followed by the full top-level usage dump — but it still exits `0`. Do not read that error text as a broken install; the version banner printed above it is the real answer. `scripts/check-prerequisites.ps1` already extracts the version line correctly and is unaffected — this note is for anyone running the command directly and reading its output by eye.

## When installed CLI conflicts with this skill

If `pac <group> <verb> help` on the user's machine shows a different argument set than what a reference file in this skill describes, **the installed CLI wins** for that workstation. Use the installed syntax, and tell the user the skill's reference is stale for this argument. Do not silently follow the skill's text over contrary evidence sitting in front of you.

## No hard-coded versions, ever

This skill never states a fixed version number for: React, Fluent UI, TypeScript, ESLint, the PAC CLI, pcf-scripts, Node.js, or any `platform-library` entry. Every version claim is read from the project (`package.json`, the manifest's `platform-library` elements, `dotnet --list-sdks`) or from current documentation at the time of use. A version number written into this skill today is wrong by the time it is read.

## Where to verify host/type/element support

Manifest element and `of-type` availability differs across model-driven apps, canvas apps, and custom pages, and it changes over time as the platform evolves. This skill does not embed a support matrix — a static one goes stale and produces confidently wrong advice. Instead:

- Check the generated scaffold for what the current PAC template already assumes for the chosen host.
- Search current official Microsoft documentation for the specific element (e.g. "PCF `data-set` canvas app support", "`external-service-usage` component framework") at the time of the manifest workshop.
- If a definitive answer cannot be found and there is no way to test in an environment (per this skill's no-deployment posture during design), say so explicitly in the manifest proposal as a compatibility warning rather than asserting support.

## Dated CLI snapshot — re-verify before relying on it

The following PAC CLI usage strings were captured directly from an installed CLI (version 1.37.4). They are a snapshot, not a contract — re-run the `help` verb before depending on any of it, since argument sets change between PAC CLI versions.

```
pac pcf init [--namespace] [--name] [--template] [--framework] [--outputDirectory] [--run-npm-install]
  --template   Values: field, dataset
  --framework  Values: none, react   (default: none)
  --run-npm-install  (default: false)

pac pcf push [--environment] [--publisher-prefix] [--solution-unique-name]
             [--verbosity] [--interactive] [--incremental] [--force-import]
  --verbosity  Values: minimal, normal, detailed, diagnostic
  --force-import  (deprecated)
  NOTE: no --path argument. Push acts on the current directory.

pac pcf version [--strategy] [--patchversion] [--path] [--allmanifests] [--updatetarget] [--filename]
  --strategy  Values: None, GitTags, FileTracking, Manifest
  --updatetarget  Values: build, project

pac solution init --publisher-name --publisher-prefix [--outputDirectory]
  Both publisher arguments are REQUIRED. No solution-name argument exists.

pac solution add-reference --path
  --path is REQUIRED.

pac solution version [--strategy] [--buildversion] [--revisionversion] [--filename] [--solutionPath] [--patchversion]
  --strategy  Values: None, GitTags, FileTracking, Solution
  --patchversion  (deprecated)
  NOTE: sets BUILD and REVISION only, not major/minor.

pac solution import [--environment] [--path] [--activate-plugins] [--force-overwrite]
                    [--skip-dependency-check] [--import-as-holding] [--stage-and-upgrade]
                    [--publish-changes] [--convert-to-managed] [--async]
                    [--max-async-wait-time] [--settings-file] [--skip-lower-version]
  --max-async-wait-time  default 60 minutes (default import is synchronous with this wait)

pac solution publish [--environment] [--async] [--max-async-wait-time]
  NOTE: no scoping arguments of any kind. Publishes ALL customizations.

pac solution check [--environment] [--path] [--solutionUrl] [--outputDirectory] [--geo]
                   [--customEndpoint] [--ruleLevelOverride] [--ruleSet] [--excludedFiles]
                   [--saveResults] [--clearCache]
  --ruleSet  Values: a Guid, "AppSource Certification", "Solution Checker" (default)

pac auth create [--name] [--username] [--password] [--applicationId] [--clientSecret]
                [--certificateDiskPath] [--certificatePassword] [--tenant] [--cloud]
                [--deviceCode] [--managedIdentity] [--githubFederated]
                [--azureDevOpsFederated] [--environment] [--kind] [--url]
  --cloud  Values: Public, UsGov, UsGovHigh, UsGovDod, China
  --kind, --url  (deprecated)
  WARNING: --password, --clientSecret, --certificatePassword accept the secret as a
  plain CLI argument. Never construct a command using these — see the safety rules
  in ../references/deployment-and-alm.md.

pac auth list      — no arguments
pac auth who       — no arguments
pac auth select [--index] [--name]

pac pcf verbs:      init, push, version
pac solution verbs: init, add-reference, list, delete, online-version, version, import,
                    export, clone, publish, upgrade, add-license, check, create-settings,
                    pack, unpack, add-solution-component, sync
```

Context for calibration: this snapshot came from a workstation with PAC CLI `1.37.4+g82c3669` installed via the standalone MSI, alongside a second PAC CLI bundled inside the VS Code extension `microsoft-isvexptools.powerplatform-vscode` — a common dual-install scenario worth checking for on any machine (see [troubleshooting.md](troubleshooting.md) for the drift this can cause).

## Recording a new deviation

When a future run discovers that installed CLI help, current documentation, or the generated project contradicts something written elsewhere in this skill, record it here as a dated one-line entry before proceeding, so the correction accumulates instead of repeating silently every session:

```
- YYYY-MM-DD: <what this skill said> vs <what was actually observed> — <source> — <resolution used>
```

- 2026-08-11: This skill originally documented only `--help` as erroring while still exiting non-zero-looking (C1). Observed directly: `pac --version` also fails argument parsing (`Error: Not a valid command`) and dumps top-level usage, while still printing the version banner and exiting `0` — a related but distinct trap. — source: direct execution on this workstation, PAC CLI 1.37.4+g82c3669 — resolution: documented above under [How to query the PAC CLI correctly](#how-to-query-the-pac-cli-correctly).

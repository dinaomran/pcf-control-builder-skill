<!--
TEMPLATE: the Gate C deployment readiness report.

Applies to test/UAT/staging/production only, always. It does NOT apply to
development at all -- not even the first deployment to a brand-new dev
environment. That case skips this template entirely in favor of a
one-line heads-up before running and the full post-deployment report
after. See
references/deployment-and-alm.md#development-deployments-run-without-a-confirmation-gate.

Fill every field before showing this to the user -- an incomplete report
is not a report. See references/deployment-and-alm.md for the rules
behind each field and the invalidation matrix in references/workflow.md.
-->

# Deployment readiness: <operation>

| Field | Value |
|---|---|
| Gate A — React design approval | `<approved (initial) YYYY-MM-DD \| overridden YYYY-MM-DD \| pending>` -- Gate A applies once per control; "approved (initial) <date>" means the design was reviewed on that date, and updates since then were **not** individually re-reviewed (see spec §5's iteration log for what shipped after) |
| Gate B — Manifest approval | `<approved (initial) YYYY-MM-DD \| pending>` -- same one-time meaning as Gate A above |
| Deployment method | `<push \| package>` -- basis: suggested default for this classification, explicit override, or user-named directly |
| Operation | `<the exact command that will run>` |
| Environment classification | `<development \| test \| UAT \| staging \| production>` |
| Exact environment URL/ID | |
| Authenticated user / profile | `<from pac auth who>` |
| Control name and version | `<current -> proposed, e.g. 1.0.1 -> 1.0.2; unchanged on the first-ever publish>` |
| Solution unique name and version | `<or "not explicitly named; pac pcf push default solution" for a no-name push>` |
| Publisher name and prefix | |
| Package type | `<Managed \| Unmanaged>` -- asked explicitly on Worksheet W7 this run, not defaulted; from SolutionPackageType + the actual artifact, not the filename |
| Exact artifact path | `<discovered, with size and timestamp>` |
| Build result | |
| Checker result | `<pac solution check output, or "not run">` |
| Publish changes requested? | `<Yes \| No>` -- explicit either way |

**Non-default import options requested** (each needs its own justification;
leave the table empty and say "none" if there are none):

| Option | Justification |
|---|---|
| | |

**Expected impact:**

<!-- what will change in the environment -->

**Rollback / recovery:**

<!-- how to revert, and whether reverting is possible at all -->

---

To proceed, type exactly (`<target-identifier>` is the solution unique name
if one is explicitly known, otherwise the control name for a no-name push):

**Test:**
```
DEPLOY <target-identifier> TO <environment-url>
```

**UAT / staging / production:**
```
CONFIRM PRODUCTION IMPORT <target-identifier> <version> TO <environment-url>
```

(Anything else -- including "yes", "ok", "go ahead" -- will not be
accepted; the required string will be re-displayed and the operation will
wait.)

This confirmation covers exactly **one** operation and is void if any file,
version, build, authentication, environment, publisher, package type, or
artifact changes after it is given.

---

## Development heads-up (not this template)

For **any** push/import to a `development` target — the first deployment
to a brand-new environment included — none of the above is shown.
Instead, immediately before running the command, show one non-blocking
line — narration, not a question, no reply expected:

```
Pushing <ControlName> v<version> to <environment-url> (development, no confirmation required)...
```

Then run it. The full
[Post-deployment verification](../references/deployment-and-alm.md#post-deployment-verification)
report — operation, version, warnings, smoke-test checklist — still runs
afterward exactly as it would for any other deployment; this is where the
user actually reviews what happened for this case, so don't compress it.

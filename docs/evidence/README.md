# Evidence

Screenshots, command output, and query results that prove each phase's claims. An
evidence file is not decoration: it is the artifact a reviewer can check against the
roadmap's "Done when" line.

## Naming

```
phase-<N>-<short-description>.<ext>
```

Examples:

- `phase-1-bad-pr.png` — the deliberately insecure PR failing CI
- `phase-1-clean-pr.png` — the clean PR passing, with runtime
- `phase-1-branch-protection.png` — required checks on `master`
- `phase-1-policy-compliance.txt` — `az policy state summarize -g zt-rg`
- `phase-3-developer-vs-auditor.mp4` — the ZTNA access demo
- `phase-5-denied-flow.kql.png` — a denied packet found in a saved query

## Rules

- **No secrets.** Redact subscription IDs if they are sensitive, tokens, tenant
  names, public IPs you do not want indexed, and user principal names. The repo is
  public.
- **No raw state or plan files.** They can contain secrets.
- **Text over screenshots when possible.** A command output (`*.txt`, `*.log`) is
  searchable and easier to diff; use an image only when the UI is the point.
- **One claim per file.** Name it after the claim, not after the tool.
- Link the file from the phase's README section or the roadmap checklist.

## What counts as evidence

| Claim | Good evidence |
|---|---|
| CI blocks a bad change | The failing check run and the job log summary |
| Tests run offline | `make test` output with no Azure credentials in the environment |
| Policies are live | `az policy assignment list` plus a denied create attempt |
| A flow is denied | A timeout/deny result and the matching log record |
| Twingate access differs by group | A short recording: developer reaches all resources, auditor only storage |
| Firewall inspection works | An allowed and a denied log line for the same pair of hosts |

If a claim cannot be evidenced yet, mark it **Planned** in the README or roadmap
rather than implying it is done.

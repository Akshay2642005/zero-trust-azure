# Phase 1 implementation plan — Automation and guardrails

**Status:** Ready for implementation — Phase 0 complete
**Scope:** R1.1–R1.7, invariants T1–T8
**Roadmap:** Phase 1
**Branch:** `master` (the roadmap says `main`; the remote default is `master`)

---

## 1. Goal and definition of done

A bad Terraform change cannot merge, and the zero-trust invariants are asserted by
offline tests rather than prose.

Done when all of the following are true:

- [ ] A deliberately insecure PR fails CI; a clean PR passes in under 5 minutes.
- [ ] `make test` runs the whole invariant suite with no Azure credentials.
- [ ] Every scanner skip has a one-line written reason.
- [ ] The new policy guardrails are assigned in `zt-rg` and visible in the
      compliance report.
- [ ] Branch protection requires the CI checks, with a screenshot in `docs/evidence/`.

---

## 2. Starting point and constraints

### 2.1 Phase 0 is complete

Phase 0 landed on 2026-10-19: `docs/THREAT-MODEL.md`, `docs/adr/` (template plus
ADR-001, 002, 003 and 006), `docs/evidence/`, and the README
"Accepted exceptions" and "Known trade-offs" sections. `ROADMAP.md` is updated.

Phase 1 can now write evidence into the folder and link CI controls from the
threat model without inventing a new structure.

### 2.2 The private registry forces a release step, not a second human PR

`envs/dev` consumes `network`, `storage`, and `policy` from the private registry at
pinned versions (`1.0.0`). Terraform resolves a module version at `init` time, so a
PR **cannot** pin `network-v1.1.0` before that tag exists. This is a hard constraint,
not a workflow preference.

The design that keeps Phase 1 to **one human PR** is:

1. **One human PR** — module code, tests, CI, and the policy assignments.
   `network` and `storage` stay pinned to `v1.0.0` (their changes are additive and
   not needed by the environment yet). The policy calls use a **local source** so
   the new `parameters` input works before `policy-v1.1.0` exists; the HCP plan is
   green because the module is in the same checkout (WS3).
2. **Tag the phase** — `git tag v1.1.0 && git push origin v1.1.0`.
3. **Release workflow runs automatically** — it diffs each `modules/<name>` against
   its last module tag, reads `modules/<name>/VERSION`, tags the changed modules
   (`network-v1.1.0`, `storage-v1.1.0`, `policy-v1.1.0`), and opens an automated
   "chore: bump module pins" PR.
4. **Merge the automated PR** — it switches the policy calls from the local source
   to the registry and bumps the network/storage pins. Its plan proves the released
   versions resolve and produce no infrastructure changes.

So: one human-authored PR plus one mechanical, generated PR. That is the minimum
that preserves both the registry and a green plan before merge. Tagging an approved
PR head is the only true single-PR alternative, and it publishes an unmerged version
to the registry; it is not recommended.

### 2.3 Tooling gaps on this machine

`terraform` (1.16.6), `tflint` (0.64.0), `checkov` (3.3.20), `gh`, and `az` are
present. `terraform-docs` and `pre-commit` are not installed. They are needed for
R1.5:

```bash
brew install terraform-docs pre-commit
```

### 2.4 Verified facts (checked against this tenant, not memory)

- Built-in policy IDs:
  - Storage public access: `b2982f36-99f2-4db5-8eff-283140c09693`
  - Storage minimum TLS: `fe83a0eb-a853-422d-aac2-1bffd182c5d0`
    (`minimumTlsVersion`)
  - Secure transfer: `404c3081-a854-4457-ae30-26a93ef643f9`
  - Require tag and value: `1e30110a-5ceb-460c-a204-c1c3969c6d62`
    (`tagName`, `tagValue`; fixed `deny` effect)
  - NIC public IPs (existing): `83a86a26-fd1f-447c-b59d-e51f44264114`
- The built-in SSH/RDP-from-Internet policies are deprecated, so the 22/3389 rule
  is a custom definition.
- NSG rule aliases exist and are usable in the custom definition. The deprecated
  built-in SSH/RDP policies confirm the exact field syntax: singular fields use
  `Microsoft.Network/networkSecurityGroups/securityRules/<field>`; plural fields use
  `…/<field>[*]` (for example `sourceAddressPrefixes[*]`).
- `terraform test` with `mock_provider "azurerm"` + `command = plan` can assert on
  dynamic `security_rule` blocks, and `expect_failures` works for a resource
  `lifecycle.precondition` (verified with a local probe).
- Current Checkov failures on the repo: `CKV_TF_1` (×3, registry module sources),
  `CKV_AZURE_33` (queue logging), `CKV_AZURE_206` (LRS replication).
- The OIDC service principal gets `Contributor` + `Resource Policy Contributor` at
  subscription scope (`scripts/setup-oidc.rb`), so it can create the subscription-level
  custom policy definitions as well as the RG-scoped assignments.

### 2.5 The HCP speculative plan, explained

A speculative plan is a **dry run of `terraform plan` shown on the PR**. It answers
"what would this change do?" and never applies anything. R1.4 asks for it.

There are three ways to get one:

| Option | How it works | Setup | Trade-off |
|---|---|---|---|
| **A. API-driven GitHub job** (recommended) | A CI job runs `terraform plan` in `envs/dev` with a Terraform Cloud token. HCP executes the plan remotely and the job shows the diff. | Add a `TF_API_TOKEN` repository secret | One extra secret, but the plan appears as a normal PR check and the workspace stays CLI-driven |
| **B. VCS-driven HCP** | Connect the GitHub repo to the HCP workspace. HCP watches PRs and runs speculative plans itself. | A few clicks in the HCP UI | No GitHub secret, but the workspace becomes VCS-driven, which can change how `terraform apply` is run |
| **C. Local plan in CI** (fallback) | CI plans a temporary copy of `envs/dev` with local module paths | None | Does not exercise the registry or HCP; does not satisfy R1.4 literally |

The token in option A is a **Terraform Cloud token, not an Azure credential**. It
only lets CI start a run in the `zero-trust-azure-dev` workspace. Azure
authentication stays OIDC inside HCP. The job is skipped for fork PRs so the token
is never exposed.

Recommendation: option A, unless the workspace is already VCS-connected, in which
case option B is less work.

---

## 3. Workstreams

### WS1 — Network invariants and the overlap guard (T1, T2, T3, T7, T5)

Files:

- `modules/network/variables.tf`
- `modules/network/main.tf`
- `modules/network/versions.tf`
- `modules/network/tests/network.tftest.hcl` (new)

Changes:

1. Add `broad_rule_exceptions` (list of objects `{ name, reason }`). Default
   contains one documented entry:
   `AllowHttpsToSpoke1Workload` — outbound HTTPS to a specific internal prefix;
   `source = "*"` means "any address in this subnet", not the internet.
2. Add a provider constraint: `version = ">= 4.81.0, < 5.0.0"` (fixes the existing
   tflint `terraform_required_providers` warning).
3. Add the T7 overlap guard:
   - Convert each configured VNet CIDR to `{ cidr, base, prefix }` in locals.
   - For every pair, compare block indices at the less-specific prefix; a match
     means one block contains the other.
   - Put a `lifecycle { precondition { ... } }` on `azurerm_virtual_network.spoke2`.
     The error message lists the overlapping pairs.
4. Test file, one run block per concern:

| Run block | Test | Assertion |
|---|---|---|
| `defaults` | T1 | All three NSGs have `DenyAllInbound` and `DenyAllOutbound` at priority 4096 |
| `defaults` | T2 | Every Allow rule using `*`, `0.0.0.0/0`, `Internet`, or `Any` is named in `var.broad_rule_exceptions` and has a non-empty reason |
| `defaults` | T2 | The documented exception is precisely shaped: `direction = Outbound`, destination = spoke workload prefix, port 443 |
| `defaults` | T3 | No Inbound Allow rule on 22/3389 has a broad source |
| `defaults` | T8 | Hub/spoke/spoke2 VNets and NSGs carry `managed-by`, `project`, `environment` |
| `overlapping_spaces` | T7 | `spoke2_address_space = ["10.1.0.0/16"]` fails with `expect_failures = [azurerm_virtual_network.spoke2]` |

T5 is not in the Phase 1 checklist because `compute`, `access`, and `egress` do not
exist yet. Add a cheap static guard now instead of waiting:

- `scripts/check-no-public-ips.sh` — fails if `resource "azurerm_public_ip"` appears
  anywhere under `modules/` except `modules/egress`.
- Wire it into `make test` and CI. T6 stays deferred to Phase 6, when route tables
  exist.

### WS2 — Storage invariants (T4, T8)

Files:

- `modules/storage/tests/storage.tftest.hcl` (new)
- `modules/storage/versions.tf` (provider constraint)

Run blocks:

| Run block | Test | Assertion |
|---|---|---|
| `defaults` | T4 | `public_network_access_enabled = false`, `min_tls_version = "TLS1_2"`, `allow_nested_items_to_be_public = false` |
| `keys_disabled` | T4 | With `shared_access_key_enabled = false`, the account has `shared_access_key_enabled = false` |
| `defaults` | T8 | Storage account, private DNS zone, DNS link, and private endpoint carry the three required tags |

No infrastructure behaviour changes in this workstream. Policy definitions and
assignments are not taggable resources (they use `metadata`), so T8 covers the
network and storage modules only.

### WS3 — Policy guardrails (R1.6)

Files:

- `modules/policy/variables.tf`, `main.tf` (add `parameters`)
- `modules/policy/tests/policy.tftest.hcl` (new)
- `envs/dev/policies.tf` (new)
- `envs/dev/main.tf`, `envs/dev/outputs.tf`

#### Approach: additive `parameters` plus a local-source bridge

The existing module cannot pass parameters, and the assignments need them (the
storage built-ins default to `Audit`; the tag policy needs `tagName`/`tagValue`).
Add an optional `parameters` string (JSON) to the module. That is additive, so the
release is `policy-v1.1.0` per SPEC §11 — no breaking rewrite.

The registry chicken-and-egg still applies: the human PR cannot consume
`policy-v1.1.0` before the tag exists. Bridge it with a local source:

- `envs/dev/policies.tf` calls `source = "../../modules/policy"` for all eight
  assignments. The module code is in the same checkout, so the HCP plan is green.
- The existing `module.deny_public_ip_on_nic` registry call is replaced by one of
  the eight local calls; `network` and `storage` stay on the registry.
- After the phase merges, the release workflow tags `policy-v1.1.0`. Its generated
  PR switches the eight policy calls to the registry source and version, and bumps
  the network/storage pins. The module code at the tag is identical to the reviewed
  merge commit, so that PR's plan is a no-op.
- The custom definition is declared in `envs/dev/policies.tf` and passed to the
  `deny-mgmt-ports` call. If we later want the module to own definitions, that is
  an additive change in a future release.

This is the only way to keep one human PR, apply the guardrails immediately, and
still end with every module consumed from the registry.

#### Assignments in `zt-rg`

| Assignment name | Definition | Effect | Enforce | Purpose |
|---|---|---|---|---|
| `deny-storage-public` | `b2982f36…` | Deny (parameter) | true | Storage public access off |
| `storage-min-tls` | `fe83a0eb…` | Deny, `minimumTlsVersion = TLS1_2` | true | TLS floor |
| `storage-secure-transfer` | `404c3081…` | Deny (parameter) | true | HTTPS only |
| `deny-mgmt-ports` | custom | Deny | true | No inbound 22/3389 from `*`, `0.0.0.0/0`, `Internet` |
| `tag-managed-by` | `1e30110a…` | Deny (built-in) | false | Staged audit; flip later |
| `tag-project` | `1e30110a…` | Deny (built-in) | false | Staged audit; flip later |
| `tag-environment` | `1e30110a…` | Deny (built-in) | false | Staged audit; flip later |
| `deny-public-ip-on-nic` | `83a86a26…` | Deny | true | Existing guardrail, preserved |

Important: the storage built-ins default their `effect` parameter to `Audit`.
"Enforced" requires both `enforce = true` **and** `parameters = jsonencode({ effect = "Deny" })`.

#### Custom definition: `deny-mgmt-ports`

Declared in `envs/dev/policies.tf` as an `azurerm_policy_definition`:

```json
{
  "if": {
    "allOf": [
      { "field": "type", "equals": "Microsoft.Network/networkSecurityGroups/securityRules" },
      { "field": "Microsoft.Network/networkSecurityGroups/securityRules/access", "equals": "Allow" },
      { "field": "Microsoft.Network/networkSecurityGroups/securityRules/direction", "equals": "Inbound" },
      { "anyOf": [
        { "equals": "*", "field": "Microsoft.Network/networkSecurityGroups/securityRules/destinationPortRange" },
        { "equals": "22", "field": "Microsoft.Network/networkSecurityGroups/securityRules/destinationPortRange" },
        { "equals": "3389", "field": "Microsoft.Network/networkSecurityGroups/securityRules/destinationPortRange" }
      ]},
      { "anyOf": [
        { "equals": "*", "field": "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix" },
        { "equals": "0.0.0.0/0", "field": "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix" },
        { "equals": "Internet", "field": "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix" },
        { "not": { "field": "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefixes[*]", "notEquals": "*" } },
        { "not": { "field": "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefixes[*]", "notEquals": "0.0.0.0/0" } },
        { "not": { "field": "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefixes[*]", "notEquals": "Internet" } }
      ]}
    ]
  },
  "then": { "effect": "Deny" }
}
```

Use the deprecated built-in `2c89a2e5-7285-40fe-afe0-ae8654b92fab` as the source of
truth for the condition structure. It also handles port ranges such as `20-25`
(which contain 22) via a `count`/`value` expression. Copy that range handling rather
than shipping an exact-match-only rule with a known evasion.

The existing `AllowHttpsFromSpoke2` rule uses the `10.2.0.0/24` source, so it will
not be denied. The deny-all rules are `access = Deny` and the egress rule is
outbound, so they are ignored too.

#### Module test

`modules/policy/tests/policy.tftest.hcl` uses a mock provider to assert:

- `parameters` is passed through to the assignment;
- `enforce = false` reaches the assignment for the tag policies;
- the existing parameterless call still plans unchanged (backward compatible).

#### Verification

The guardrails are verified live after apply:

- `az policy assignment list -g zt-rg -o table` shows all eight assignments;
- `az policy state summarize -g zt-rg` returns a compliance summary;
- a throwaway NSG with `Internet:22` is rejected with
  `RequestDisallowedByPolicy` (allow 10–15 minutes for propagation), then deleted.

### WS4 — CI pipeline (R1.1, R1.2, R1.4, R1.7)

Files:

- `.github/workflows/ci.yml` (new)
- `.checkov.yaml` (new)
- `.tflint.hcl` (new)
- `scripts/ci-validate-env.sh` (new)
- `docs/CI.md` (new)

#### Jobs

| Job | Steps | Notes |
|---|---|---|
| `terraform` | `terraform fmt -recursive -check -diff`; `make validate-all`; `make test`; `tflint --init`; `tflint --recursive` | No Azure credentials |
| `security` | `checkov -d . --config-file .checkov.yaml` | Pinned Checkov version |
| `plan` | `terraform -chdir=envs/dev init && plan` on same-repo PRs only | Advisory; never applies |

Details:

- Triggers: `pull_request` and `push` to `master`.
- `permissions: contents: read`; concurrency cancels superseded runs.
- Pin Terraform `1.16.6`, tflint `0.64.0`, azurerm ruleset `0.32.0`, Checkov
  `3.3.20`.
- Cache `TF_PLUGIN_CACHE_DIR` keyed on the lock file to keep the run under 5 minutes.
- `make validate-all` validates each module, then validates `envs/dev` through a
  temporary copy whose registry sources are rewritten to local `modules/*` paths.
  This keeps CI credential-free. HCP speculative plan covers the real registry path.
- `plan` job guard: `github.event.pull_request.head.repo.full_name == github.repository`
  so fork PRs never see the HCP token. Requires a `TF_API_TOKEN` repository secret
  with access to the `zero-trust-azure-dev` workspace.
- If the workspace is already VCS-driven, skip the `plan` job and rely on HCP's
  automatic speculative plans instead. Confirm this before building the job.

#### TFLint config

```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
```

#### Checkov skips (each with a written reason, in `.checkov.yaml` and `docs/CI.md`)

```yaml
skip-check:
  # CKV_TF_1: modules come from the private HCP registry, pinned by semantic
  # version. Registry modules do not support git commit-hash revisions.
  - CKV_TF_1
  # CKV_AZURE_33: the queue service is not used; only blob is exposed.
  - CKV_AZURE_33
  # CKV_AZURE_206: LRS is deliberate for a short-lived lab (cost control).
  # There is no DR requirement; revisit before any production use.
  - CKV_AZURE_206
```

No blanket skips. Any future skip must be added with a comment.

### WS5 — Local automation and docs (R1.3, R1.5)

Files:

- `Makefile`
- `.pre-commit-config.yaml` (new)
- `.terraform-docs.yml` (new)
- `modules/network/README.md`, `modules/storage/README.md`, `modules/policy/README.md` (new)
- `.gitignore` (ignore module lock files generated by tests)

Make targets:

| Target | Behaviour |
|---|---|
| `fmt`, `fmt-check` | Existing, unchanged |
| `validate` | Existing: `envs/dev` only |
| `validate-modules` | `init -backend=false` + `validate` in every module |
| `validate-all` | `validate-modules` + `scripts/ci-validate-env.sh` |
| `test` | `T5` static guard + `init -backend=false` + `terraform test` per module |
| `lint` | `tflint --recursive` |
| `security` | `checkov -d . --config-file .checkov.yaml` |
| `verify` | `fmt-check validate-all test lint security` |
| `docs` | `terraform-docs` per module, inject markers |
| `hooks` | Check binaries, then `pre-commit install` |
| `tools` | Print/install the missing CLI prerequisites |

Pre-commit hooks: `terraform_fmt`, `terraform_validate`, `terraform_tflint`,
`terraform_docs`, plus basic whitespace/YAML checks. `terraform_validate` on
`envs/dev` needs a local `terraform login` token because of the private registry;
document that in `docs/CI.md`.

Module README stubs get `<!-- BEGIN_TF_DOCS -->` markers so injection is stable.

### WS6 — Module release automation (SPEC §11)

This is the "on release, bump the modules that changed" workflow.

Files:

- `modules/network/VERSION`, `modules/storage/VERSION`, `modules/policy/VERSION`
  (new; initial values `1.1.0`, `1.1.0`, `1.1.0`)
- `scripts/check-module-versions.sh` (new)
- `scripts/release-modules.sh` (new)
- `.github/workflows/release-modules.yml` (new)

#### Version discipline in CI

`check-module-versions.sh` runs in the `terraform` job with full git history:

1. For each module, find its last tag (`git tag -l "<name>-v*" --sort=-v:refname`).
2. If `git diff <last-tag>..HEAD -- modules/<name>` is non-empty, the `VERSION`
   file must be **greater** than the last tag.
3. Fail with a clear message if a module changed but its version did not.

This catches the common mistake before merge and makes the release deterministic.

#### On a phase tag

`.github/workflows/release-modules.yml` triggers on `push` of tags matching `v*`
(and has `workflow_dispatch` for a dry run):

1. Checkout with `fetch-depth: 0` and full tags.
2. For each module, read `VERSION`; if it is greater than the last module tag,
   create and push `<name>-v<VERSION>`.
3. Rewrite the matching `version` pins in `envs/dev/main.tf` for the released
   modules, and switch the eight policy calls from the local source to the registry
   source with `version = "1.1.0"`.
4. Open a PR titled `chore(release): bump module pins for v1.1.0` using `gh`.
   Branch protection stays intact; the PR runs the full CI and HCP plan.
5. Re-running the workflow is idempotent: existing tags and an existing PR are
   skipped.

This gives the desired one-human-PR flow: the phase PR merges, tagging `v1.1.0`
does the module detection and pin bump automatically, and the generated PR proves
the released versions.

### WS7 — Speculative plan, branch protection, evidence (R1.4, R1.7)

- Connect the plan job or HCP VCS integration; document the exact console steps in
  `docs/CI.md`.
- Enable branch protection on `master`:
  - required checks: `terraform`, `security`;
  - require branches to be up to date;
  - no force pushes or deletions.
  The repo is public, so branch protection is available on the free plan.
- Evidence in `docs/evidence/`:
  - `phase-1-bad-pr.png` — a PR with an `Internet:22` allow rule failing CI;
  - `phase-1-clean-pr.png` — a clean PR passing, with runtime;
  - `phase-1-branch-protection.png`;
  - `phase-1-policy-compliance.txt` — `az policy state summarize -g zt-rg`.

The bad PR is a throwaway branch (`ci/bad-change-demo`); it is closed, never merged.

---

## 4. Delivery sequence

### PR 1 — the one human PR

1. Add provider constraints to `network` and `storage`; add `VERSION` files
   (`network` `1.1.0`, `storage` `1.1.0`, `policy` `1.1.0`).
2. Add the network overlap precondition, `broad_rule_exceptions`, and tests
   T1/T2/T3/T7/T8.
3. Add storage tests T4/T8.
4. Add `parameters` to `modules/policy` plus its test; add `envs/dev/policies.tf`
   with eight calls to the local policy module and the raw custom definition;
   update `envs/dev/main.tf` and `outputs.tf`.
5. Add `.github/workflows/ci.yml`, `.github/workflows/release-modules.yml`,
   `.tflint.hcl`, `.checkov.yaml`, `scripts/ci-validate-env.sh`,
   `scripts/check-module-versions.sh`, `scripts/release-modules.sh`.
6. Add Makefile targets, pre-commit, terraform-docs, module READMEs.
7. Add `docs/CI.md` with the skip table, HCP plan setup, release workflow, and
   branch-protection steps.
8. Run `make verify` locally; open the PR; confirm all jobs pass in under 5 minutes
   and the plan shows only the policy additions.
9. Merge.

### Apply and verify the guardrails

1. Apply through HCP (the phase PR's changes are now live).
2. Verify:
   - `az policy assignment list -g zt-rg -o table`
   - `az policy state summarize -g zt-rg`
   - create a throwaway NSG with `Internet:22` and confirm
     `RequestDisallowedByPolicy`; delete it. Allow 10–15 minutes after apply for
     the assignment to take effect before concluding the policy is broken.
3. Save the compliance output to `docs/evidence/`.

### Phase release — `v1.1.0`

```bash
git tag v1.1.0
git push origin v1.1.0
```

The release workflow then:

1. Tags `network-v1.1.0`, `storage-v1.1.0`, and `policy-v1.1.0`.
2. Opens the automated `chore(release): bump module pins for v1.1.0` PR, which also
   switches the policy calls from the local source to the registry.
3. The bot PR runs CI + the HCP plan; merging it shows no infrastructure change.

### Evidence and branch protection

1. Enable branch protection on `master`; capture the screenshot.
2. Open the deliberately bad PR; capture the failing run; close it.
3. Update `ROADMAP.md` checkboxes/status, README badges/CI section, and
   `docs/PHASE-1-PLAN.md` status.

---

## 5. Requirement traceability

| Requirement | Workstream | Verification |
|---|---|---|
| R1.1 CI workflow | WS4 | Bad PR fails; clean PR passes; runtime recorded |
| R1.2 justified scanner skips | WS4 | `.checkov.yaml` comments + `docs/CI.md` table |
| R1.3 offline `terraform test` | WS1, WS2 | `make test` with no Azure env vars |
| R1.4 speculative plan | WS4, WS7 | PR check shows plan summary |
| R1.5 pre-commit + terraform-docs | WS5 | `make hooks`; generated module READMEs |
| R1.6 policy guardrails | WS3 | Assignments list + compliance summary + denied bad NSG |
| R1.7 branch protection | WS7 | Screenshot in `docs/evidence/` |
| SPEC §11 release automation | WS6 | `v1.1.0` tag creates module tags + pin-bump PR |
| T1, T2, T3, T7 | WS1 | `modules/network/tests/network.tftest.hcl` |
| T4 | WS2 | `modules/storage/tests/storage.tftest.hcl` |
| T5 | WS1 (static guard) | `scripts/check-no-public-ips.sh` |
| T6 | Deferred to Phase 6 | Needs `egress` module and route tables |
| T8 | WS1, WS2 | Tag assertions in both test files |

---

## 6. Risks and open decisions

| Risk / decision | Impact | Mitigation / recommendation |
|---|---|---|
| Registry release ordering | A single PR cannot consume a version that does not exist yet | One human PR uses a local source for the policy module; the automated release PR pins all modules to the registry |
| Policy local-source bridge | The human PR plans the local module, not the registry artifact | The release tag points at the same merge commit; the generated PR switches to `policy-v1.1.0` and its plan is a no-op |
| Custom policy JSON is only validated at apply time | A wrong alias could leave the guardrail silently ineffective | Apply in `zt-rg`, run the throwaway `Internet:22` NSG test, inspect `az policy state` |
| Tag policies use `enforce = false` | They will not deny until enabled | Intentional staged rollout; documented; flip after the backlog is tagged |
| HCP plan job needs a token and a CLI-driven workspace | Plan job may not run on first attempt | Confirm workspace mode first; fall back to VCS speculative plans |
| Checkov/tflint rule drift | CI can go red without a code change | Pin tool versions; cache providers |
| Mocked tests give false confidence (roadmap risk) | A plan-only test can miss provider behaviour | Keep the HCP real plan; verify policies live after PR 1 is applied |
| `terraform fmt`/validate on `envs/dev` needs registry auth locally | Pre-commit validate fails on a fresh machine | Document `terraform login`; CI uses the local-source mirror |
| Branch is `master`, roadmap says `main` | Workflow triggers target the wrong branch | Use `master`; update roadmap wording or rename later |

### Decisions

1. **Phase 0:** done — see PR #1 (threat model, ADRs, evidence folder, README exceptions/trade-offs).
2. **HCP speculative plan:** see §2.5. Recommended: API-driven GitHub job with
   `TF_API_TOKEN`. If the workspace is already VCS-connected, use VCS speculative
   plans instead.
3. **Release flow:** decided — one human PR, then the `v1.1.0` release workflow
   detects changed modules, tags them, and opens the automated release PR (pin bumps
   plus the policy source switch). This is the closest safe equivalent to "one PR".
   Tagging an approved PR head is the only true one-PR alternative and is not
   recommended.

---

## 7. Effort estimate

| Workstream | Estimate |
|---|---|
| Phase 0 docs | done |
| WS1 network tests + guard | 3–4 h |
| WS2 storage tests | 1 h |
| WS3 policy `parameters` + assignments + custom definition + test | 3–4 h |
| WS4 CI + scanner + tflint | 2–3 h |
| WS5 Makefile + pre-commit + terraform-docs | 1–2 h |
| WS6 release automation | 2–3 h |
| WS7 apply, evidence, branch protection | 2–3 h |
| **Total** | **~1 weekend** (matches the roadmap) |

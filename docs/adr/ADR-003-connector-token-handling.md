# ADR-003: Stage connector token handling — cloud-init first, Key Vault later

- **Status:** Accepted
- **Date:** 2026-10-19
- **Deciders:** Akshay
- **Related:** SPEC R3.2, R3.7, R4.6; roadmap Phases 3 and 4; flow F4

## Context

The Twingate connector needs two secrets: an access token and a refresh token. They
must reach the connector VM without a public IP and without committing them to the
repository.

Phase 3 needs a working connector quickly, before Key Vault and managed identities
exist. Phase 4 adds Key Vault (RBAC mode, private endpoint) and the connector VM
gets a system-assigned identity. That creates a deliberate staging problem: the
first implementation will be less secure than the target.

## Decision

Stage the handling:

1. **Phase 3:** inject the tokens through `custom_data` (cloud-init) from sensitive
   Terraform variables sourced from HCP workspace variables. Mark the variables,
   the connector-token resource, and the outputs `sensitive`. Do not log the
   rendered user data.
2. **Phase 4:** move the tokens to Key Vault. The connector VM fetches them at boot
   with its managed identity. Remove the tokens from `custom_data` and from the
   Terraform plan.

The temporary state is an accepted exception, tracked in the README trade-offs and
the threat model. It is not allowed to survive Phase 4.

## Consequences

### Positive

- Phase 3 can prove ZTNA without waiting for Key Vault.
- The migration is a known, scoped change (one cloud-init path plus RBAC).
- Tokens never enter git; they live in HCP workspace variables and, later, Key Vault.

### Negative / accepted costs

- During Phase 3 the token is visible in the VM's custom data/metadata and in
  Terraform state. Anyone with read access to the VM or the state could retrieve it.
- Token rotation is manual in Phase 3.
- Two token paths exist briefly; the old one must be deleted, not just unused.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Key Vault from day one | Adds a private endpoint, DNS link, RBAC, and identity work before the connector can be tested; delays Phase 3. |
| Token in a plain file on disk | Worse: no secret manager, no audit trail, and still in the image or repo history. |
| Long-lived token in the image | Unacceptable: a secret in a build artifact. |
| No connector (use Bastion/SSH instead) | Does not demonstrate identity-based ZTNA, which is the point of Phase 3. |

## Review

Phase 4, requirement R4.6. The exit criterion is: `custom_data` contains no token,
the connector still reports Online, and the token is only readable by the VM's
managed identity through Key Vault.

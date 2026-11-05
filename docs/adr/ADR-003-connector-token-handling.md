# ADR-003: Connector Token Handling via Cloud-Init in Phase 3, Key Vault in Phase 4

- **Status:** Accepted
- **Date:** 2026-11-05
- **Phase:** 3 (implementation), 4 (improvement)
- **Related:** SPEC R3.7, R4.6; ADR-004

## Context

The Twingate connector VM requires an access token, a refresh token, and a network name to authenticate against the Twingate controller and join the remote network. The connector initiates outbound connections exclusively and has no public IP address.

To provision this connector autonomously via Terraform and `cloud-init`, credentials must be delivered to the VM on boot.

Two approaches were considered:
1. **Pass tokens via `custom_data` / cloud-init template (Phase 3).**
   Straightforward to wire using the `Twingate/twingate` Terraform provider. However, the sensitive tokens are stored in the Terraform state file (managed securely within HCP Terraform) and within VM instance metadata (`custom_data`).
2. **Fetch tokens from Azure Key Vault via System-Assigned Managed Identity (Phase 4).**
   Secrets are stored in Key Vault with RBAC-only access and private endpoint reachability. The VM authenticates using Azure IMDS managed identity to retrieve its connector tokens on boot, keeping the tokens entirely out of VM metadata and user-data fields.

Because `module.keyvault` and private DNS for Key Vault (`privatelink.vaultcore.azure.net`) are scheduled for Phase 4 along with data-plane identity work, provisioning Key Vault early would invert the architectural dependency flow and complicate Phase 3.

## Decision

In **Phase 3**, pass the Twingate connector tokens to the connector VM via base64-encoded `custom_data` (cloud-init).

Mark the tokens and sensitive values as `sensitive = true` in Terraform module outputs and HCP workspace variables. State is hosted remotely in HCP Terraform with encryption at rest and role-based access control.

In **Phase 4**, migrate the token storage to `module.keyvault`. The connector VM's system-assigned managed identity will be granted secret read permissions via Azure RBAC, and the VM startup script will pull the tokens directly from Key Vault over the private endpoint.

## Consequences

### Positive
- Unblocks Phase 3 identity-based access without requiring the Key Vault module, private endpoint, and RBAC infrastructure upfront.
- Allows rapid validation of Twingate connectivity and the DNS resolution path for storage private endpoints.

### Negative / Accepted Risks
- Connector tokens exist temporarily in plain text within cloud-init runtime logs (`/var/log/cloud-init-output.log`) and VM metadata.
- Tokens exist in the HCP Terraform state file. Access to HCP Terraform state must remain strictly restricted.

## Replacement Trigger (Phase 4)
When Phase 4 introduces `module.keyvault` and test workloads:
1. Store Twingate connector tokens in Key Vault secrets.
2. Grant the connector VM's managed identity `Key Vault Secrets User`.
3. Update cloud-init to retrieve tokens via `az` CLI or direct IMDS token request to the Key Vault REST API over its private endpoint.
4. Remove the tokens from `custom_data` parameters in `module.access`.

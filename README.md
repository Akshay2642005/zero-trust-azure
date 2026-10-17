# Zero-Trust Azure Network (Terraform)

A production-oriented, hub-and-spoke network on Azure: a default-deny network
fabric, a private-only storage workload reachable solely through a private
endpoint, and a control-plane guardrail that blocks public IPs on network
interfaces.

The configuration is split into reusable modules with a single environment
root, so the same fabric can be deployed to any number of environments.

## Architecture

```
                   ┌──────────────────────────────────────────────┐
                   │                Resource group: zt-rg          │
                   │                                              │
   hub-vnet  ◄─────┼── bidirectional VNet peering ──►  spoke-vnet │
   10.0.0.0/16     │                                    10.1.0.0/16│
                   │  hub-default       spoke-workload            │
                   │  10.0.1.0/24       10.1.0.0/24               │
                   │                    spoke-private-endpoints   │
                   │                    10.1.1.0/24               │
                   │                                              │
                   │  Default-deny NSGs on hub-default and        │
                   │  spoke-workload.                             │
                   │                                              │
                   │  ztstorage (public access disabled)          │
                   │      ▲                                       │
                   │      └── pe-storage-blob (private endpoint)  │
                   │              delegated into spoke-private-…  │
                   │              resolved via privatelink.blob…  │
                   │                                              │
                   │  Policy: deny public IPs on NICs (enforced)  │
                   └──────────────────────────────────────────────┘
```

## Repository layout

```
modules/
  network/   hub + two spoke VNets, subnets, default-deny NSGs, VNet peering
  storage/   private storage account, blob private endpoint, private DNS zone
  policy/    resource-group policy assignment (guardrails)
envs/
  dev/       the dev environment root: providers, backend, variables,
             locals (naming + tags), module wiring and outputs
```

Each module is self-contained: it declares its own inputs and outputs, takes a
`naming` object so names live in one place, and tags everything it creates.

The modules are published to the HCP Terraform **private registry** and the dev
root consumes them by version (`app.terraform.io/akshay2642005/<name>/azurerm`),
so it no longer reaches up to `../../modules`. Publishing a new module version
is a separate, explicit step — see [Usage](#usage).

## What it creates

| Resource | Notes |
|----------|-------|
| Resource group | `zt-rg`, managed by Terraform |
| `hub-nsg`, `spoke-nsg`, `spoke2-nsg` | default-deny inbound **and** outbound |
| `hub-vnet` (10.0.0.0/16) | hub network |
| `spoke-vnet` (10.1.0.0/16) | first workload network |
| `spoke2-vnet` (10.2.0.0/16) | second, isolated workload segment |
| `hub-default`, `spoke-workload`, `spoke2-workload` | subnets with the NSGs associated |
| `spoke-private-endpoints` | open subnet reserved for private endpoints |
| bidirectional peering | hub↔each spoke, plus a direct spoke1↔spoke2 pair |
| HTTPS allow (spoke2 → spoke1) | the one exception to default-deny: 443 to the spoke1 workload subnet |
| `ztstorage` | StorageV2, TLS 1.2+, HTTPS-only, public access disabled |
| `privatelink.blob.core.windows.net` | private DNS zone, linked to the spoke VNet |
| `pe-storage-blob` | private endpoint + DNS zone group |
| `deny-public-ip-on-nic` | Azure Policy assignment, enforced |

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `subscription_id` | Target Azure subscription | — |
| `location` | Azure region | `eastus` |
| `environment` | Environment name used in tags | `dev` |
| `storage_account_name` | Globally unique storage account name | — |
| `hub_address_space` | Hub VNet address space | `["10.0.0.0/16"]` |
| `spoke_address_space` | Spoke VNet address space | `["10.1.0.0/16"]` |
| `hub_default_subnet_prefix` | Hub default subnet | `10.0.1.0/24` |
| `spoke_workload_subnet_prefix` | Spoke workload subnet | `10.1.0.0/24` |
| `spoke_pe_subnet_prefix` | Spoke private-endpoints subnet | `10.1.1.0/24` |
| `spoke2_address_space` | Second spoke VNet address space | `["10.2.0.0/16"]` |
| `spoke2_workload_subnet_prefix` | Second spoke workload subnet | `10.2.0.0/24` |
| `allow_forwarded_traffic` | Allow forwarded traffic across peerings | `true` |
| `tags` | Extra tags merged into the common tags | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `resource_group_name` | Resource group name |
| `hub_vnet_id` | Hub VNet resource ID |
| `spoke_vnet_id` | Spoke VNet resource ID |
| `spoke2_vnet_id` | Second spoke VNet resource ID |
| `storage_account_name` | Storage account name |
| `storage_private_endpoint_id` | Blob private endpoint resource ID |
| `storage_private_endpoint_ip` | Private IP allocated to the endpoint |
| `policy_assignment_id` | Deny-public-IP-on-NIC assignment ID |

## Usage

State is held in HCP Terraform (Terraform Cloud). See `envs/dev/backend.tf`
for the workspace configuration.

```bash
# One-time
terraform login
# edit envs/dev/backend.tf -> set your organization, then:
make init

# Per change
make fmt        # terraform fmt -recursive
make validate
make plan
make apply
make destroy
```

Copy `envs/dev/terraform.tfvars.example` to `envs/dev/terraform.tfvars`
(git-ignored) and fill in `subscription_id` and `storage_account_name`.

### Modules and the private registry

The root module consumes the shared modules from the HCP Terraform private
registry, pinned by version:

```hcl
module "network" {
  source  = "app.terraform.io/akshay2642005/network/azurerm"
  version = "1.0.0"
}
```

This is why `make plan` works as a remote run: the modules are resolved over
the registry instead of being uploaded from a path outside the configuration
directory. The `modules/` directory in this repo remains the source of truth
for those registry entries.

To publish a new module version after changing one of the modules, bump the
version and upload it with the helper script (the modules are published without
VCS backing, so each version is uploaded explicitly):

```bash
export TF_TOKEN_app_terraform_io=...        # an HCP token with "Manage modules"
scripts/publish-module.sh network 1.1.0    # network | storage | policy

# point the root at the new version, then confirm it resolves
# (edit envs/dev/main.tf -> version = "1.1.0")
terraform -chdir=envs/dev init -backend=false
make plan
```

### Authentication (OIDC)

The workspace authenticates to Azure with HCP Terraform dynamic credentials
(OpenID Connect) — no stored client secret. `scripts/setup-oidc.rb` wires both
halves: the Azure app registration + federated identity credentials and the
workspace environment variables.

```bash
scripts/setup-oidc.rb \
  --subscription <sub-id> --tenant <tenant-id> \
  --dry-run          # preview, then drop --dry-run to apply
```

## Security posture

- **Default deny** — all three NSGs drop all inbound and outbound traffic
  unless a higher-priority rule allows it.
- **Microsegmentation** — each spoke is isolated by its own deny-all NSG.
  spoke2 reaches spoke1's workload subnet over HTTPS (443) and nothing else; a
  third segment follows the same pattern.
- **No public data plane** — the storage account has public network access
  disabled; it is reachable only through the private endpoint, and only from
  the peered network.
- **Private name resolution** — `privatelink.blob.core.windows.net` is linked
  to the spoke VNet so the storage FQDN resolves to the endpoint's private IP.
- **Guardrail** — the enforced `deny-public-ip-on-nic` policy rejects any NIC
  in the resource group that has a public IP, preventing drift away from the
  private design.

## Notes

- The private-endpoints subnet is intentionally left without an NSG so that
  private-link traffic is not dropped before it reaches the endpoint.
- The spoke2 → spoke1 HTTPS flow needs both NSG rules (egress on spoke2,
  ingress on spoke1) and the direct spoke1↔spoke2 peering — hub-and-spoke
  alone does not route between spokes without an NVA.
- The storage account name must be globally unique and match
  `^[a-z0-9]{3,24}$`; the variable validates this before any plan runs.

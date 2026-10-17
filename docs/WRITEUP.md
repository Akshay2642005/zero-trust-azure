# Build Journal — Zero Trust Network on Azure with Terraform

> The original step-by-step journal from the NextWork project, kept here as a
> record of the build. For the technical reference, see
> [`ARCHITECTURE.md`](ARCHITECTURE.md); for the summary, see the
> [README](../README.md).

**Project:** [Zero Trust Network on Azure with Terraform](https://nextwork.ai/projects/9627fa86-3b65-4e7e-a83c-69105c804da2)
**Author:** Akshay B — akshay2642005@gmail.com

![Cover](cover.png)

---

## 1. Architecture intent and Zero Trust principles

The goal: build a zero-trust network on Azure using Terraform, where nothing is
trusted by default. Every flow is denied unless it is explicitly permitted, and
every allowance is visible in one place.

## 2. Setting up the project and authenticating with Azure

Set up Terraform and Azure so the environment can create resources — the HCP
Terraform workspace authenticates to Azure through OIDC federation, with no
stored client secret.

### Why provider version pinning matters

Pinning the provider version (`azurerm = 4.81.0`) ensures everyone runs the same
version, so there are no incompatibilities or surprise breakages — and the
committed dependency lock file resolves identical provider versions on every
run.

## 3. Deploying a hub-and-spoke network with deny-all NSGs

Built the network foundation that enforces "assume breach", to learn hub-and-spoke
topology and Network Security Groups.

### Enforcing 'assume breach' with deny-all rules

The deny-all rule enforces *assume breach* because Zero Trust operates on a
deny-by-default basis: any traffic that is not explicitly permitted is treated
as potentially malicious.

## 4. Locking down storage with a private endpoint

Added a private DNS zone and a private endpoint so the storage account can only
be reached via a private IP inside the spoke VNet.

### How the private endpoint secures data access

A private endpoint gives the storage account a private IP address inside the
spoke VNet. Once public access is disabled, the only path to the data goes
through the network — so the NSGs actually protect the data.

## 5. Enforcing Zero Trust guardrails with Azure Policy

Set up Azure Policy as a guardrail so that public IPs cannot be attached to any
network interface in the resource group.

### How Azure Policy complements NSGs and private endpoints

Azure Policy enforces the principle of *preventive, secure-by-default
governance* — that security is a property of the platform, not a matter of
developer discipline. It acts on the **control plane** at deploy time, while
NSGs act on the **data plane** at runtime; together they are defense in depth.

## 6. Scaling Zero Trust with a second spoke and microsegmentation

### Priority ordering and microsegmentation logic

The priority ordering makes microsegmentation the default outcome, not the
exception — NSG rules are evaluated in ascending priority order and the first
matching rule wins, terminating evaluation. A single narrowly-scoped allow at
priority `100` (HTTPS 443, spoke2 → spoke1) sits above the `4096` deny-all, so
everything else falls through to deny.

---

## Reflections and takeaways

### Key tools and concepts learned

I learnt to build an Azure network where security is enforced by construction —
Terraform modules, HCP Terraform's private registry and remote state, and
secretless OIDC — and where Zero Trust, microsegmentation, and
control-plane-vs-data-plane enforcement are expressed as code: default-deny NSGs
with priority-ordered allow-by-exception rules, plus an Azure Policy guardrail
that keeps the topology private.

### Time and challenges

About 1 hour end to end — most of it spent designing the modules and debugging
policy and peering edge cases, rather than writing the Terraform itself.

### Personal reflection

I did this project to learn how to design and ship a genuinely default-deny,
Zero Trust network on Azure.

---

*Originally completed as a [NextWork](https://nextwork.ai) project —
[view this project](https://nextwork.ai/projects/9627fa86-3b65-4e7e-a83c-69105c804da2).*

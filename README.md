# Terraform IaC Patterns

[![Terraform](https://github.com/detahermana/terraform-iac-patterns/actions/workflows/terraform.yml/badge.svg)](https://github.com/detahermana/terraform-iac-patterns/actions/workflows/terraform.yml)

A collection of Terraform modules that encode how I structure infrastructure as
code across Azure, AWS, and GCP. Each module is small, opinionated, and
documented with the reasoning behind its choices — not just what it creates.

These are general-purpose patterns, written from scratch. They are not a copy
of any client or employer configuration; no real account IDs, subscription IDs,
domains, addresses, or resource names appear anywhere in this repository.

## Modules

| Module | Provider | What it does |
|---|---|---|
| [`azure-network`](modules/azure-network) | Azure | Resource group, VNet, subnets with optional service delegation, NSG with ordered rules, subnet associations |
| [`azure-linux-vm`](modules/azure-linux-vm) | Azure | Linux VM with NIC, optional data disk, SSH-key-only access, Azure Monitor agent |
| [`azure-app-service`](modules/azure-app-service) | Azure | App Service plan and web app: HTTPS-only, VNet-integrated, deny-by-default IP restrictions, optional Entra ID auth |
| [`aws-network`](modules/aws-network) | AWS | VPC, public/private subnets across AZs, internet gateway, named security groups with explicit ingress and egress |
| [`gcp-vm`](modules/gcp-vm) | GCP | VPC, subnet, tag-scoped firewall rules, private compute instance with Shielded VM |

## Design principles

**Secure defaults, not secure options.** The modules make the safe choice the
default and require effort to weaken it. `azure-app-service` always sets
`https_only` and defaults both IP restriction actions to `Deny` — there is no
variable to turn that off. `gcp-vm` gives an instance no public IP unless asked.

**Explicit over implicit.** `aws-network` requires egress to be declared for
every security group, rather than inheriting the AWS default allow-all rule.
Outbound traffic should be a decision, not an omission.

**The reasoning ships with the code.** Each module README explains *why* a
structure was chosen — why the NIC is separate from the VM, why delegation lives
on the subnet object, why AZs are resolved rather than hard-coded. A module
without its rationale is only half useful to the next engineer.

**Bounded scope.** One module, one concern. `azure-app-service` does not create
the subnet it integrates with; `azure-network` does not create the VM that uses
its subnet. Composition happens at the call site, and the examples show it.

**Lifecycle-aware.** Where a field is legitimately managed outside Terraform —
backup tags, platform-side NIC attachment, image patching — the module ignores
changes to it, so a routine apply does not fight the platform.

## Repository layout

```
.
├── modules/
│   ├── azure-network/
│   ├── azure-linux-vm/
│   ├── azure-app-service/
│   ├── aws-network/
│   └── gcp-vm/
└── examples/
    ├── azure-app-service/    # network + app service wired together
    ├── aws-web-server/       # two-tier VPC with referenced security groups
    └── gcp-vm/               # private instance with IAP-only SSH
```

Each module directory contains `main.tf`, `variables.tf`, `outputs.tf`, and a
`README.md`.

## Using a module

Reference it by relative path, or point at a tagged release of this repository.

```hcl
module "network" {
  source = "git::https://github.com/detahermana/terraform-iac-patterns.git//modules/azure-network?ref=v1.0.0"

  resource_group_name = "rg-uks-p-app"
  location            = "uksouth"
  vnet_name           = "vnet-uks-p-app"
  address_space       = ["10.20.0.0/16"]

  subnets = {
    app = {
      name             = "snet-uks-p-app"
      address_prefixes = ["10.20.1.0/24"]
    }
  }
}
```

## Validating

Every module and example in this repository passes `terraform fmt -check`,
`terraform validate`, `tflint`, and a Trivy misconfiguration scan. These run
automatically in CI on every push and pull request — see
[`.github/workflows/terraform.yml`](.github/workflows/terraform.yml).

To check locally:

```bash
# Format
terraform fmt -check -recursive

# Validate every module (provider download, no apply)
for d in modules/*/ examples/*/; do
  (cd "$d" && terraform init -backend=false -input=false && terraform validate)
done
```

## Conventions

**Naming.** Resources are named from a small set of parts —
`<type>-<region>-<environment>-<workload>` — so a resource is identifiable from
its name alone: `vm-uks-p-portal` is a VM in UK South, production, the portal
workload.

**Tagging.** Tags are passed in as a map and applied to everything the module
creates. The modules do not invent tags; the caller owns the taxonomy.

**Variables.** Inputs are typed. Optional structured inputs use
`object` types with defaults on the individual fields, so a caller can set one
field without repeating the rest.

## State

These modules do not configure a backend. State location is a deployment
decision, not a module decision. For any shared or production use, configure a
remote backend with encryption and locking.

State contains sensitive values, including generated passwords and secrets.
Treat the state file as a secret.

## License

MIT — see [LICENSE](LICENSE).

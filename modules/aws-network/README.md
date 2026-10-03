# aws-network

Creates a VPC with public and private subnets, an internet gateway with routing
for the public tier, and named security groups with explicit rules.

## What it creates

| Resource | Notes |
|---|---|
| `aws_vpc` | DNS support and hostnames enabled |
| `aws_subnet` (public) | One per CIDR, spread across AZs, auto-assign public IP |
| `aws_subnet` (private) | One per CIDR, spread across AZs, no public IP |
| `aws_internet_gateway` | Optional |
| `aws_route_table` (public) | Routes `0.0.0.0/0` to the gateway |
| `aws_route_table_association` | Binds public subnets to the public route table |
| `aws_security_group` | One per entry in `var.security_groups` |

## Why AZs are resolved, not hard-coded

`data.aws_availability_zones` is queried at plan time. Hard-coding `eu-west-1a`
makes the module region-specific and breaks silently if an AZ is renamed or
unavailable. Resolving from the region keeps the module portable.

## Why egress is explicit

The module does not add a default allow-all egress rule. Every `aws_security_group`
must state its egress. AWS creates an allow-all egress rule by default; leaving
that in place means an application tier can reach the entire internet, which is
rarely the intent. Making egress a required declaration turns outbound traffic
into a deliberate decision.

## Why security groups are a map

Groups are keyed by name so that one group can reference another by key before
either exists — `security_groups = [module.network.security_group_ids["sg-web-lb"]]`.
That is the pattern for a tiered application: the app tier accepts traffic only
from the load balancer's group, expressed by reference rather than by CIDR.

## Usage

```hcl
module "network" {
  source = "../../modules/aws-network"

  vpc_name = "vpc-web-tier"

  vpc_cidr             = "10.30.0.0/16"
  public_subnet_cidrs  = ["10.30.1.0/24", "10.30.2.0/24"]
  private_subnet_cidrs = ["10.30.11.0/24", "10.30.12.0/24"]

  tags = local.tags

  security_groups = {
    "sg-app" = {
      description = "Application tier."
      ingress = [
        {
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = ["10.30.0.0/16"]
        }
      ]
      egress = [
        {
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
    }
  }
}
```

## Two modes

The module creates a VPC, or attaches to an existing one:

- `vpc_id = null` (default) — creates a new VPC from `vpc_cidr`
- `vpc_id = "vpc-..."` — attaches to an existing VPC, useful for adding
  subnets or security groups to a VPC another call already created

The second mode is what makes a tiered application possible without a
dependency cycle. A security group that accepts traffic only from the load
balancer's group must reference that group by ID — and if both groups were
declared in the same module call, the call's input would depend on its own
output. Splitting into two calls, the second passing `vpc_id`, expresses the
dependency cleanly. See `examples/aws-web-server`.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `vpc_name` | `string` | — | VPC Name tag and name prefix |
| `vpc_cidr` | `string` | `10.0.0.0/16` | VPC CIDR (ignored when `vpc_id` is set) |
| `vpc_id` | `string` | `null` | Existing VPC to attach to |
| `public_subnet_cidrs` | `list(string)` | `[]` | Public subnet CIDRs |
| `private_subnet_cidrs` | `list(string)` | `[]` | Private subnet CIDRs |
| `create_internet_gateway` | `bool` | `true` | Create IGW and public routing |
| `security_groups` | `map(object)` | `{}` | Named security groups |
| `tags` | `map(string)` | `{}` | Tags for all resources |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID |
| `vpc_cidr` | VPC CIDR block |
| `public_subnet_ids` | Public subnet IDs, in input order |
| `private_subnet_ids` | Private subnet IDs, in input order |
| `internet_gateway_id` | IGW ID, or `null` |
| `security_group_ids` | Map of group name to ID |

## Note

Private subnets are created without a NAT gateway. Instances in them have no
outbound internet access until one is added. That is intentional: a NAT gateway
is a cost and a routing decision the caller should make explicitly.

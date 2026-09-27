# Pterodactyl on Oracle Cloud with Terraform

[![terraform](https://github.com/guilhermedecastrogt/pterodactyl-oracle-terraform/actions/workflows/terraform.yml/badge.svg)](https://github.com/guilhermedecastrogt/pterodactyl-oracle-terraform/actions/workflows/terraform.yml)

Infrastructure as code for running a full **Pterodactyl** game-server panel on
an ARM VM in Oracle Cloud's **Always Free** tier. One `terraform apply` creates
the network, the firewall rules and the machine, then brings up the panel, its
database, the Wings daemon and an HTTPS reverse proxy — with a working
certificate and an admin account already created.

From there you manage Minecraft servers, mods and modpacks from a web UI
instead of editing YAML over SSH.

```
terraform apply
      │
      ▼
 Oracle Cloud (home region only — Always Free is region-locked)
      │
      ├── VCN 10.0.0.0/16
      │     ├── Internet Gateway · Route Table
      │     ├── Security List  :22 · :80 · :443 · :2022 · :25565-25585 (tcp+udp)
      │     └── Subnet 10.0.1.0/24 (public)
      │
      └── VM  VM.Standard.A1.Flex · Ubuntu 24.04 ARM
            │
            └── cloud-init (first boot)
                  ├── installs Docker
                  ├── opens the same ports in the in-VM iptables
                  └── docker compose up
                        ├── caddy      → TLS for panel.<domain> and node.<domain>
                        ├── panel      → Pterodactyl (PHP + nginx)
                        ├── database   → MariaDB
                        ├── cache      → Redis
                        └── wings      → spawns one container per game server
```

**Cost: $0** within Always Free, with a USD 1 budget alert wired in as a
tripwire in case anything ever leaves the free tier.

---

## Layout

```
.
├── .github/workflows/terraform.yml   CI: fmt, validate and cloud-init lint
├── scripts/
│   ├── check-cloud-init.sh           renders the template and validates it
│   └── apply-retry.sh                reapplies until ARM capacity frees up
└── terraform/
    ├── versions.tf                   Terraform and provider constraints
    ├── providers.tf                  OCI authentication
    ├── variables.tf                  every knob the project exposes
    ├── secrets.tf                    generated DB, app and admin credentials
    ├── network.tf                    VCN, IGW, route table, security list, subnet
    ├── compute.tf                    Ubuntu ARM image lookup + A1.Flex instance
    ├── budget.tf                     spend tripwire (optional)
    ├── outputs.tf                    panel URL and credentials after apply
    ├── templates/
    │   └── cloud-init.yaml.tftpl     the whole stack, written at first boot
    └── terraform.tfvars.example
```

## Sizing

Pterodactyl is a stack, not a container: panel, MariaDB, Redis, Caddy and Wings
together take roughly **1.5 GB of RAM** before a single game server starts.

| Setup | `instance_ocpus` | `instance_memory_gb` | Room left for servers |
|---|---|---|---|
| Minimum that makes sense | 2 | 12 | ~10 GB |
| Comfortable | 4 | 24 | ~22 GB |

The default is 2 / 12. Larger requests are meaningfully harder to schedule on
the free ARM pool — see [when ARM capacity runs out](#when-arm-capacity-runs-out).

## Requirements

| What | How to get it |
|---|---|
| Oracle Cloud account | [cloud.oracle.com](https://cloud.oracle.com) — a card is required, but Always Free resources are not billed |
| Terraform ≥ 1.5 | `brew install terraform` |
| SSH key pair | `ssh-keygen -t ed25519` |
| OCI API key | Console → profile → **My profile** → **API keys** → **Add API key** |
| A domain | **optional** — see below |

### About the domain

The panel needs real DNS to get a real certificate. If you leave `panel_domain`
empty, the stack uses [sslip.io](https://sslip.io), a public resolver that maps
any hostname containing an IP back to that IP. The VM discovers its own public
address at boot and serves:

```
https://panel.<your-ip>.sslip.io
https://node.<your-ip>.sslip.io
```

No DNS to configure, and Let's Encrypt still issues a valid certificate. Set
`panel_domain = "example.com"` if you own one and prefer `panel.example.com`;
point an `A` record for `panel` and `node` at the instance IP first.

## Deploying

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars      # credentials, SSH key, panel_admin_email

terraform init
terraform plan
terraform apply
```

Passwords for MariaDB, the Laravel `APP_KEY` and the panel admin are generated
by Terraform, so there is nothing to invent. Read them back with:

```bash
terraform output panel_url
terraform output panel_admin_username
terraform output -raw panel_admin_password
```

First boot takes **5 to 10 minutes**: Docker install, five images pulled for
arm64, database migrations and certificate issuance. Follow along with:

```bash
ssh ubuntu@<IP> 'sudo tail -f /var/log/cloud-init-output.log'
```

When it prints `panel ready at https://panel...`, log in.

## After the first login

Terraform creates the panel, the admin user and a location. Registering the
node is deliberately manual — the panel generates a token that only exists
after you create it.

**1. Create the node.** Admin → Nodes → Create New:

| Field | Value |
|---|---|
| Name | anything |
| Location | `oci` (already created) |
| FQDN | the `node_fqdn` output, e.g. `node.150.230.x.x.sslip.io` |
| Communicate over SSL | **yes** |
| Behind proxy | **yes** |
| Daemon port | **443** |
| Memory / Disk | leave ~2 GB and a few GB of disk for the host |

The SSL and proxy settings matter: Caddy terminates TLS and forwards to Wings
on plain 8080 inside the Docker network.

**2. Hand the config to Wings.** Open the node's **Configuration** tab, copy the
YAML, then on the VM:

```bash
sudo nano /etc/pterodactyl/config.yml     # paste, save
cd /opt/pterodactyl && docker compose restart wings
docker logs -f wings                      # should report it is listening
```

The node turns green in the panel once Wings checks in.

**3. Add allocations.** Node → Allocations. IP is the instance's public
address, ports `25565-25585` — the range the firewall already allows.

**4. Create a server.** Servers → Create New, nest **Minecraft**, egg
**Paper**, **Vanilla**, **Forge** or **Fabric**. Mods and modpacks are managed
from the panel's file manager and startup variables from here on.

## Running it

```bash
ptero ps               # stack status
ptero-logs             # all panel logs
wings-logs             # daemon logs
ptero-artisan          # php artisan inside the panel container
```

| Path | Contents |
|---|---|
| `/opt/pterodactyl/docker-compose.yml` | the stack |
| `/opt/pterodactyl/bootstrap.sh` | first-boot script, safe to re-run |
| `/opt/pterodactyl/data/` | database, panel state, Caddy certificates |
| `/etc/pterodactyl/config.yml` | Wings configuration |
| `/var/lib/pterodactyl/volumes/` | the game servers' files |

Backups are configured per server from the panel, which is why this project no
longer ships a backup container.

**Tearing everything down** (every server goes with it):

```bash
terraform destroy
```

## How the pieces fit together

**There are two firewalls, and both must allow the port.** The OCI security
list filters before packets reach the VM; iptables inside Ubuntu filters after,
and Oracle's image ships blocking everything except SSH. cloud-init opens the
same ports on the inside. Forgetting one of them is the usual cause of "the
panel is up but the server is unreachable".

**Wings publishes ports it does not own.** Game containers are created by Wings
through the Docker socket as siblings, and they bind the host directly. That is
why the `wings` service publishes only SFTP (2022): publishing the game range
there too would collide with "port is already allocated" the moment a server
starts.

**cloud-init runs exactly once.** Editing the template and reapplying recreates
the machine, taking every game server with it. Day-to-day changes belong on the
VM, or in the panel. Terraform owns the infrastructure; the panel owns the
servers.

**The base image is looked up, not pinned.** `compute.tf` queries the newest
Ubuntu ARM image instead of hardcoding an OCID. An `ignore_changes` on
`source_id` keeps a new Oracle image release from recreating the VM.

## Cost guardrail

Everything here is meant to sit inside Always Free, so **any spend at all is a
bug**. `budget.tf` encodes that as a USD 1 monthly budget alerting at 100%,
which in practice fires on the first cent.

```hcl
budget_alert_email = "you@example.com"
```

Leave it empty and no budget is created. This matters most on **Pay As You Go**
accounts: a trial account refuses to exceed the free quota, while a PAYG
account happily does and charges the card.

## CI

Every push and pull request runs:

- `terraform fmt -check -recursive`
- `terraform init -backend=false` + `terraform validate`
- `scripts/check-cloud-init.sh` — renders the template and asserts the
  cloud-init document, the five-service compose file and the bootstrap script
  come out intact, with no unrendered interpolation leaking through

Validation only; there is no automatic `apply`, which would need OCI
credentials as repository secrets.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `Out of host capacity` | free ARM capacity exhausted. See below |
| Panel unreachable, certificate errors | Caddy could not complete the ACME challenge. Check `docker logs panel-proxy`; port 80 must be open |
| Node stays red | `/etc/pterodactyl/config.yml` missing or stale — recopy it and restart Wings |
| Wings restarting in a loop | expected until the node config exists |
| `port is already allocated` | something else claimed a port in the allocation range |
| Server won't start, out of memory | the panel lets you over-allocate; leave ~2 GB for the host |

## When ARM capacity runs out

`Out of host capacity` is not a configuration error: the region's free Ampere
A1 pool is full. The apply creates everything else and fails only on the
instance, so reapplying resumes from there.

```bash
./scripts/apply-retry.sh                 # retry every 3 minutes
INTERVAL=300 ./scripts/apply-retry.sh    # every 5 minutes
MAX_TRIES=20 ./scripts/apply-retry.sh    # give up after 20 attempts
```

Three things improve the odds:

1. **Ask for less.** Smaller shapes are far easier to place. 2 OCPUs and 12 GB
   is the floor for this stack.
2. **Check your home region before switching regions.** Always Free resources
   only exist in the tenancy's home region, fixed at account creation.
   Deploying elsewhere works, but is billed.
3. **Leave the trial.** Trial accounts sit lower in the capacity queue, and the
   upgrade to Pay As You Go keeps Always Free resources free.

`availability_domain_index` only helps in regions with more than one
availability domain — `sa-saopaulo-1`, for instance, has a single one.

## Roadmap

- [ ] Remote state in OCI Object Storage + CI-driven `apply` via OIDC
- [ ] Register the node automatically through the panel's application API
- [ ] Ship panel backups to Object Storage with `rclone`
- [ ] Metrics with Prometheus + Grafana

## License

MIT.

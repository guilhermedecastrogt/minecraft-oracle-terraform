# Minecraft on Oracle Cloud with Terraform

[![terraform](https://github.com/guilhermedecastrogt/minecraft-oracle-terraform/actions/workflows/terraform.yml/badge.svg)](https://github.com/guilhermedecastrogt/minecraft-oracle-terraform/actions/workflows/terraform.yml)

Infrastructure as code for running a **Paper** Minecraft server on an ARM VM in
Oracle Cloud's **Always Free** tier. A single `terraform apply` creates the
network, the firewall rules and the machine, installs Docker and brings the
server online — no manual steps afterwards.

This is a learning project: the goal is a real server to play on with friends
and, along the way, hands-on exposure to VCNs, security lists, cloud-init, ARM
images, Docker Compose and CI.

```
terraform apply
      │
      ▼
 Oracle Cloud (sa-saopaulo-1)
      │
      ├── VCN 10.0.0.0/16
      │     ├── Internet Gateway
      │     ├── Route Table        0.0.0.0/0 → IGW
      │     ├── Security List      :22 (your IP) · :25565 (world) · ICMP
      │     └── Subnet 10.0.1.0/24 (public)
      │
      └── VM  VM.Standard.A1.Flex · 4 ARM OCPUs · 24 GB · Ubuntu 24.04
            │
            └── cloud-init (first boot)
                  ├── installs Docker
                  ├── opens 25565 in the in-VM iptables
                  └── docker compose up
                        ├── itzg/minecraft-server  →  Paper + Aikar flags
                        └── itzg/mc-backup         →  snapshot every 6 h
```

**Cost: $0** within Always Free — 4 ARM OCPUs, 24 GB of RAM and 200 GB of disk,
with no expiry date. This project uses exactly that budget, and ships an
optional OCI budget alert as a tripwire in case anything ever leaves the free
tier.

---

## Layout

```
.
├── .github/workflows/terraform.yml   CI: fmt, validate and cloud-init lint
├── scripts/
│   ├── check-cloud-init.sh           renders the template and validates the YAML
│   └── apply-retry.sh                reapplies until ARM capacity frees up
└── terraform/
    ├── versions.tf                   Terraform and provider constraints
    ├── providers.tf                  OCI authentication
    ├── variables.tf                  every knob the project exposes
    ├── network.tf                    VCN, IGW, route table, security list, subnet
    ├── compute.tf                    Ubuntu ARM image lookup + A1.Flex instance
    ├── budget.tf                     spend tripwire (optional)
    ├── outputs.tf                    IP and ready-to-run commands after apply
    ├── templates/
    │   └── cloud-init.yaml.tftpl     what runs on the VM's first boot
    └── terraform.tfvars.example
```

## Requirements

| What | How to get it |
|---|---|
| Oracle Cloud account | [cloud.oracle.com](https://cloud.oracle.com) — a card is required, but Always Free resources are not billed |
| Terraform ≥ 1.5 | `brew install terraform` |
| SSH key pair | `ssh-keygen -t ed25519 -C "minecraft"` |
| OCI API key | Console → profile → **My profile** → **API keys** → **Add API key** |

Creating the API key opens a **Configuration file preview**. That is where
`tenancy_ocid`, `user_ocid`, `fingerprint` and `region` come from. Download the
private key, save it as `~/.oci/oci_api_key.pem` and `chmod 600` it.

> Upgrade the account to **Pay As You Go** if you can. Trial accounts almost
> always hit `Out of host capacity` when requesting ARM. Everything stays free
> as long as you remain within the Always Free limits.

## Deploying

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

terraform init
terraform plan
terraform apply
```

Beyond the credentials, these are the settings worth reviewing:

| Variable | Default | Why you'd change it |
|---|---|---|
| `allowed_ssh_cidr` | `0.0.0.0/0` | find your IP with `curl ifconfig.me` and set `YOUR_IP/32` |
| `ops` | empty | usernames granted operator rights (`You,AFriend`) |
| `whitelist` | empty | filling it in enables whitelist enforcement automatically |
| `java_memory` | `12G` | JVM heap; leave headroom for the OS and Docker |
| `difficulty` / `max_players` / `motd` | `normal` / `20` / — | gameplay settings |
| `timezone` | `America/Sao_Paulo` | affects container logs and backup scheduling |
| `server_type` | `PAPER` | `VANILLA`, `FABRIC`, `FORGE`... anything itzg/minecraft-server accepts |
| `view_distance` / `simulation_distance` | `10` / `8` | the biggest CPU levers on small instances |
| `budget_alert_email` | empty | email for the spend alert; empty disables the budget |

After the apply:

```
server_address = "150.230.x.x:25565"
ssh            = "ssh ubuntu@150.230.x.x"
```

The VM boots in about a minute, but cloud-init still has to install Docker and
download Paper — **3 to 6 minutes end to end**. To follow along:

```bash
ssh ubuntu@<IP> 'sudo tail -f /var/log/cloud-init-output.log'   # provisioning
ssh ubuntu@<IP> 'docker logs -f minecraft'                      # the server
```

Once `Done (x.xxxs)! For help, type "help"` shows up, paste `server_address`
into Minecraft under **Multiplayer → Add Server**.

## Running the server

Log in with `ssh ubuntu@<IP>`. These aliases are already in the shell:

```bash
mc-logs        # follow the logs
mc-console     # Paper console over RCON
mc-restart     # restart the container
mc-up          # bring the compose stack up
mc-down        # tear it down
```

Inside `mc-console`:

```
list
op YourName
whitelist add AFriend
say hello
stop
```

Where things live on the VM:

| Path | Contents |
|---|---|
| `/opt/minecraft/docker-compose.yml` | container definitions |
| `/opt/minecraft/data/` | world, `server.properties`, `plugins/`, logs |
| `/opt/minecraft/backups/` | automatic backups (every 6 h, 7-day retention) |

**Installing a plugin:**

```bash
scp EssentialsX.jar ubuntu@<IP>:/opt/minecraft/data/plugins/
ssh ubuntu@<IP> 'docker restart minecraft'
```

**Downloading a backup:**

```bash
scp ubuntu@<IP>:/opt/minecraft/backups/*.tgz .
```

**Tearing everything down** (the world goes with it — grab the backups first):

```bash
terraform destroy
```

## Cost guardrail

Everything here is designed to sit inside Always Free, so **any spend at all is
a bug**, not a cost to optimize. `budget.tf` encodes that: a USD 1 monthly
budget with an alert at 100%, which in practice fires on the first cent.

```hcl
budget_alert_email = "you@example.com"
```

Leave it empty and no budget is created — the `count` on both resources drops
to zero. The budget itself lives in the tenancy root, which is where OCI
requires budgets to be created, and targets the compartment this project
deploys into.

This matters most on **Pay As You Go** accounts. A trial account simply refuses
to create anything beyond the free quota; a PAYG account happily creates it and
charges the card. The budget is what turns that silent failure mode into an
email.

## How the pieces fit together

Three things that tend to trip people up:

**There are two firewalls, and both must allow the port.** The OCI *security
list* filters packets before they reach the VM. The *iptables* rules inside
Ubuntu filter them afterwards — and Oracle's Ubuntu image ships blocking
everything except SSH. That is why cloud-init also opens 25565 from the inside.
Remembering one and forgetting the other is the number one cause of "the server
is up but nobody can connect".

**cloud-init runs exactly once.** It is handed to the VM as `user_data` at
birth. Editing the template and applying again **recreates the machine**, and
the world goes with it. For day-to-day changes, edit on the VM instead:

```bash
sudo nano /opt/minecraft/docker-compose.yml
docker compose -f /opt/minecraft/docker-compose.yml up -d
```

In practice: Terraform owns the **infrastructure**; from first boot onwards,
game configuration lives on the VM.

**The base image is looked up, not pinned.** `compute.tf` queries the newest
Ubuntu ARM image rather than hardcoding an OCID, because those IDs change with
every release. Since that would otherwise recreate the VM whenever Oracle
publishes a new image, there is an `ignore_changes` on `source_id`. Patch the
OS from the inside with `apt`.

## CI

The workflow runs on every push and pull request:

- `terraform fmt -check -recursive` — formatting
- `terraform init -backend=false` + `terraform validate` — syntax and types
- `scripts/check-cloud-init.sh` — renders the template and asserts that the
  cloud-init document and the embedded `docker-compose.yml` are valid YAML with
  the expected services

Validation only: there is no automatic `apply`, since that would require OCI
credentials as repository secrets. Getting there is the first item on the
roadmap.

To run the same checks locally:

```bash
cd terraform && terraform fmt -check -recursive && terraform validate
./scripts/check-cloud-init.sh
```

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `Out of host capacity` | free ARM capacity exhausted. See the section below |
| `404-NotAuthorizedOrNotFound` | wrong OCID, fingerprint or key path in `terraform.tfvars` |
| SSH works, the game does not connect | in-VM firewall. Check `sudo iptables -L INPUT -n --line-numbers` |
| `Connection refused` in the client | Paper is still downloading or generating the world. Check `docker logs minecraft` |
| Server stuttering with a full lobby | raise `java_memory`, or lower `view_distance` and `simulation_distance` |

## When ARM capacity runs out

`Out of host capacity` is the most common obstacle in this project, and it is
**not a configuration error**: the region's free Ampere A1 pool is full. The
apply creates the network normally and fails only on the instance, so
reapplying resumes from there — nothing has to be redone.

Capacity opens in short windows, whenever someone destroys an instance.
Persistence pays off:

```bash
./scripts/apply-retry.sh                 # retry every 3 minutes until it lands
INTERVAL=300 ./scripts/apply-retry.sh    # every 5 minutes
MAX_TRIES=20 ./scripts/apply-retry.sh    # give up after 20 attempts
```

The script only retries on capacity errors; anything else it prints and stops.

If the wait drags on, three things improve the odds:

1. **Ask for less.** Requesting 4 OCPUs and 24 GB needs one large free block.
   Smaller requests are far easier to place, and a handful of players needs
   surprisingly little:

   | Players | `instance_ocpus` | `instance_memory_gb` | `java_memory` | `view_distance` |
   |---|---|---|---|---|
   | up to 5 | 1 | 6 | `4G` | 8 |
   | up to 12 | 2 | 12 | `8G` | 10 |
   | 12+ | 4 | 24 | `12G` | 12 |

   Minecraft's tick loop is essentially single-threaded, so extra cores buy
   less than you would expect — render distance and heap matter more.
2. **Switch regions — but check your home region first.** Always Free resources
   can only be created in the tenancy's **home region**, which is fixed when the
   account is created. Deploying to any other region works, but it is billed.
   Check yours under Governance → Tenancy details before changing `region`.
3. **Leave the trial.** Trial accounts sit lower in the capacity queue.
   Upgrading to Pay As You Go helps and keeps Always Free resources free.

Note that `availability_domain_index` only helps in regions with more than one
availability domain — `sa-saopaulo-1`, for instance, has a single one.

If you are stuck, the single most effective move is usually the upgrade to Pay
As You Go: trial accounts sit lower in the ARM capacity queue, and the upgrade
keeps Always Free resources free. Pair it with the budget above.

## Roadmap

- [ ] Remote state in OCI Object Storage + CI-driven `apply` via OIDC
- [ ] Custom domain with an SRV record (drops the port from the address)
- [ ] Geyser + Floodgate so Bedrock players can join
- [ ] Ship backups to Object Storage with `rclone`
- [ ] Server metrics with Prometheus + Grafana

## License

MIT.

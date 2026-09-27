#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../terraform"

EXPR='templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {minecraft_port=25565, minecraft_version="LATEST", java_memory="12G", motd="ci", difficulty="normal", max_players=20, ops="", whitelist="", enforce_whitelist="false", rcon_password="ci"})'

terraform init -backend=false -input=false >/dev/null

echo "$EXPR" | terraform console \
  -var tenancy_ocid=ci \
  -var user_ocid=ci \
  -var fingerprint=ci \
  -var ssh_public_key=ci \
  | sed '1d;$d' > /tmp/cloud-init.rendered.yaml

python3 - <<'PY'
import yaml

doc = yaml.safe_load(open("/tmp/cloud-init.rendered.yaml"))
compose = yaml.safe_load(doc["write_files"][0]["content"])

assert "runcmd" in doc, "runcmd ausente no cloud-init"
assert set(compose["services"]) == {"mc", "backup"}, compose["services"]
assert compose["services"]["mc"]["environment"]["TYPE"] == "PAPER"

print("cloud-init e docker-compose validos")
PY

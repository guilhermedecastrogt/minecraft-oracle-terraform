#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../terraform"

EXPR='templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {timezone="UTC", region="ci", panel_domain="", panel_admin_email="ci@example.com", panel_admin_username="admin", panel_admin_first_name="Server", panel_admin_last_name="Admin", panel_admin_password="ci", app_key="base64:ci", db_root_password="ci", db_password="ci", game_port_min=25565, game_port_max=25585})'

terraform init -backend=false -input=false >/dev/null

echo "$EXPR" | terraform console \
  -var tenancy_ocid=ci \
  -var user_ocid=ci \
  -var fingerprint=ci \
  -var ssh_public_key=ci \
  -var panel_admin_email=ci@example.com \
  | sed '1d;$d' > /tmp/cloud-init.rendered.yaml

python3 - <<'PY'
import yaml

doc = yaml.safe_load(open("/tmp/cloud-init.rendered.yaml"))
files = {f["path"]: f["content"] for f in doc["write_files"]}
compose = yaml.safe_load(files["/opt/pterodactyl/docker-compose.yml"])

expected = {"database", "cache", "panel", "wings", "proxy"}
assert "runcmd" in doc, "cloud-init has no runcmd section"
assert set(compose["services"]) == expected, compose["services"]
assert "/var/run/docker.sock" in str(compose["services"]["wings"]["volumes"])
assert compose["services"]["panel"]["environment"]["APP_URL"].startswith("https://panel.")

bootstrap = files["/opt/pterodactyl/bootstrap.sh"]
assert "p:user:make" in bootstrap, "admin bootstrap is missing"
assert "${" not in bootstrap.replace("${BASE_DOMAIN}", "").replace("${PUBLIC_IP}", "").replace("${CONFIGURED_DOMAIN}", ""), \
    "an unrendered Terraform interpolation leaked into the script"

print("cloud-init, docker-compose and bootstrap render correctly")
PY

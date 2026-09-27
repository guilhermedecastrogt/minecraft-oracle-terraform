resource "random_password" "db_root" {
  length  = 32
  special = false
}

resource "random_password" "db_user" {
  length  = 32
  special = false
}

resource "random_password" "panel_admin" {
  count = var.panel_admin_password == "" ? 1 : 0

  length           = 20
  override_special = "!@#%^*-_=+"
}

resource "random_id" "app_key" {
  byte_length = 32
}

locals {
  panel_admin_password = var.panel_admin_password != "" ? var.panel_admin_password : random_password.panel_admin[0].result
  app_key              = "base64:${random_id.app_key.b64_std}"
}

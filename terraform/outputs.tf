locals {
  base_domain = var.panel_domain != "" ? var.panel_domain : "${oci_core_instance.mc.public_ip}.sslip.io"
}

output "public_ip" {
  description = "Public IP address of the VM."
  value       = oci_core_instance.mc.public_ip
}

output "panel_url" {
  description = "Pterodactyl panel URL."
  value       = "https://panel.${local.base_domain}"
}

output "node_fqdn" {
  description = "FQDN to use when creating the node in the panel (SSL on, port 443, behind proxy)."
  value       = "node.${local.base_domain}"
}

output "panel_admin_username" {
  description = "Username of the panel admin created at first boot."
  value       = var.panel_admin_username
}

output "panel_admin_password" {
  description = "Password of the panel admin. Read with: terraform output -raw panel_admin_password"
  value       = local.panel_admin_password
  sensitive   = true
}

output "ssh" {
  description = "Command to log into the machine."
  value       = "ssh ubuntu@${oci_core_instance.mc.public_ip}"
}

output "bootstrap_log" {
  description = "Command to follow first-boot provisioning."
  value       = "ssh ubuntu@${oci_core_instance.mc.public_ip} 'sudo tail -f /var/log/cloud-init-output.log'"
}

output "budget" {
  description = "Monthly budget guarding against accidental spend, when enabled."
  value       = var.budget_alert_email != "" ? "USD ${var.budget_amount}/month, alerting ${var.budget_alert_email} at 100%" : "disabled (set budget_alert_email to enable)"
}

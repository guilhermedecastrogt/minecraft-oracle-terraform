output "public_ip" {
  description = "Public IP address of the VM."
  value       = oci_core_instance.mc.public_ip
}

output "server_address" {
  description = "Address to paste into Minecraft under Multiplayer > Add Server."
  value       = "${oci_core_instance.mc.public_ip}:${var.minecraft_port}"
}

output "ssh" {
  description = "Command to log into the machine."
  value       = "ssh ubuntu@${oci_core_instance.mc.public_ip}"
}

output "logs" {
  description = "Command to follow the server logs."
  value       = "ssh ubuntu@${oci_core_instance.mc.public_ip} 'docker logs -f minecraft'"
}

output "cloud_init_log" {
  description = "Command to follow first-boot provisioning."
  value       = "ssh ubuntu@${oci_core_instance.mc.public_ip} 'sudo tail -f /var/log/cloud-init-output.log'"
}

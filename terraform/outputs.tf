output "public_ip" {
  description = "IP público da VM."
  value       = oci_core_instance.mc.public_ip
}

output "server_address" {
  description = "Endereço para colar no Minecraft em Multiplayer > Add Server."
  value       = "${oci_core_instance.mc.public_ip}:${var.minecraft_port}"
}

output "ssh" {
  description = "Comando para entrar na máquina."
  value       = "ssh ubuntu@${oci_core_instance.mc.public_ip}"
}

output "logs" {
  description = "Comando para acompanhar os logs do servidor."
  value       = "ssh ubuntu@${oci_core_instance.mc.public_ip} 'docker logs -f minecraft'"
}

output "cloud_init_log" {
  description = "Comando para acompanhar o provisionamento do primeiro boot."
  value       = "ssh ubuntu@${oci_core_instance.mc.public_ip} 'sudo tail -f /var/log/cloud-init-output.log'"
}

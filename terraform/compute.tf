locals {
  compartment_id = var.compartment_ocid != "" ? var.compartment_ocid : var.tenancy_ocid
  shape          = "VM.Standard.A1.Flex"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = local.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = var.ubuntu_version
  shape                    = local.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"

  filter {
    name   = "display_name"
    values = ["^Canonical-Ubuntu-${var.ubuntu_version}-aarch64-.*"]
    regex  = true
  }
}

resource "oci_core_instance" "mc" {
  compartment_id      = local.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
  display_name        = var.instance_name
  shape               = local.shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.mc.id
    assign_public_ip = true
    hostname_label   = "minecraft"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key

    user_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      minecraft_port    = var.minecraft_port
      minecraft_version = var.minecraft_version
      java_memory       = var.java_memory
      motd              = var.motd
      difficulty        = var.difficulty
      max_players       = var.max_players
      timezone          = var.timezone
      ops               = var.ops
      whitelist         = var.whitelist
      enforce_whitelist = var.whitelist != "" ? "true" : "false"
      rcon_password     = var.rcon_password
    }))
  }

  preserve_boot_volume = false

  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}

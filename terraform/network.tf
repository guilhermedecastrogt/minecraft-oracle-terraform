resource "oci_core_vcn" "mc" {
  compartment_id = local.compartment_id
  display_name   = "${var.instance_name}-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "mcvcn"
}

resource "oci_core_internet_gateway" "mc" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.mc.id
  display_name   = "${var.instance_name}-igw"
  enabled        = true
}

resource "oci_core_route_table" "mc" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.mc.id
  display_name   = "${var.instance_name}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.mc.id
  }
}

resource "oci_core_security_list" "mc" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.mc.id
  display_name   = "${var.instance_name}-sl"

  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }

  ingress_security_rules {
    source      = var.allowed_ssh_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    description = "SSH"

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    description = "HTTP (Let's Encrypt challenge and redirect)"

    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    description = "HTTPS (panel and daemon)"

    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    description = "Wings SFTP"

    tcp_options {
      min = 2022
      max = 2022
    }
  }

  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    description = "Game servers (TCP)"

    tcp_options {
      min = var.game_port_min
      max = var.game_port_max
    }
  }

  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "17"
    description = "Game servers (UDP)"

    udp_options {
      min = var.game_port_min
      max = var.game_port_max
    }
  }

  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "1"
    description = "Path MTU discovery"

    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_subnet" "mc" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.mc.id
  display_name               = "${var.instance_name}-subnet"
  cidr_block                 = "10.0.1.0/24"
  route_table_id             = oci_core_route_table.mc.id
  security_list_ids          = [oci_core_security_list.mc.id]
  prohibit_public_ip_on_vnic = false
  dns_label                  = "mcsubnet"
}

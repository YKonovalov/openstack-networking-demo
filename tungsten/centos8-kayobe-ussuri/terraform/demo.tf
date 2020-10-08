variable "demo" { type = string }
variable "public_keys" { type = string }
variable "catalog_name" { type = string }
variable "template_name" { type = string }
variable "edge_gateway" { type = string }
variable "network_name" { type = string }
variable "translated_address" { type = string }
variable "original_address" { type = string }
variable "gateway" { type = string }
variable "netmask" { type = string }
variable "dhcp_pool_start_address" { type = string }
variable "dhcp_pool_end_address" { type = string }
variable "static_ip_pool_start_address" { type = string }
variable "static_ip_pool_end_address" { type = string }
variable ip_compute1 { type = string }
variable ip_compute2 { type = string }
variable ip_compute3 { type = string }
variable ip_control { type = string }
variable ip_head { type = string }
variable user_data_compute1 { type = string }
variable user_data_compute2 { type = string }
variable user_data_compute3 { type = string }
variable user_data_control { type = string }
variable user_data_head { type = string }

resource "vcd_vapp" "demo" {
  name = var.demo
  guest_properties = {
    "public-keys" = var.public_keys
  }
}

resource "vcd_network_routed" "demo" {
  name               = var.demo
  gateway            = var.gateway
  netmask            = var.netmask
  dns1               = "8.8.8.8"
  dns2               = "8.8.4.4"
  dns_suffix         = var.demo
  edge_gateway       = var.edge_gateway
  dhcp_pool {
    start_address = var.dhcp_pool_start_address
    end_address   = var.dhcp_pool_end_address
    max_lease_time = 2147483647
  }
  static_ip_pool {
    start_address = var.static_ip_pool_start_address
    end_address   = var.static_ip_pool_end_address
  }
}

resource "vcd_vapp_org_network" "demo" {
  vapp_name        = vcd_vapp.demo.name
  org_network_name = vcd_network_routed.demo.name
}

resource "vcd_nsxv_snat" "demo" {
  edge_gateway = var.edge_gateway
  network_type = "ext"
  network_name = var.network_name

  original_address   = var.original_address
  translated_address = var.translated_address
}


resource "vcd_vapp_vm" "head" {
  vapp_name     = vcd_vapp.demo.name
  name          = "head.${var.demo}"
  computer_name = "head.${var.demo}"
  catalog_name  = var.catalog_name
  template_name = var.template_name
  memory        = 65536
  cpus          = 8
  cpu_cores     = 1
  metadata = {
    role    = "head"
    env     = "demo"
  }
  guest_properties = {
    "hostname"   = "head.${var.demo}"
    "user-data" = var.user_data_head
  }
  override_template_disk {
    bus_type         = "paravirtual"
    size_in_mb       = "51200"
    bus_number       = 0
    unit_number      = 0
    iops             = 0
  }
  network {
    type               = "org"
    name               = vcd_vapp_org_network.demo.org_network_name
    ip_allocation_mode = "MANUAL"
    ip                 = var.ip_head
    is_primary         = true
  }
}
resource "vcd_vapp_vm" "compute1" {
  vapp_name     = vcd_vapp.demo.name
  name          = "compute1.${var.demo}"
  computer_name = "compute1.${var.demo}"
  catalog_name  = var.catalog_name
  template_name = var.template_name
  memory        = 8192
  cpus          = 2
  cpu_cores     = 1
  metadata = {
    role    = "compute"
    env     = "demo"
  }
  guest_properties = {
    "hostname"   = "compute1.${var.demo}"
    "user-data" = var.user_data_compute1
  }
  override_template_disk {
    bus_type         = "paravirtual"
    size_in_mb       = "51200"
    bus_number       = 0
    unit_number      = 0
    iops             = 0
  }
  network {
    type               = "org"
    name               = vcd_vapp_org_network.demo.org_network_name
    ip_allocation_mode = "MANUAL"
    ip                 = var.ip_compute1
    is_primary         = true
  }
}

resource "vcd_vapp_vm" "compute2" {
  vapp_name     = vcd_vapp.demo.name
  name          = "compute2.${var.demo}"
  computer_name = "compute2.${var.demo}"
  catalog_name  = var.catalog_name
  template_name = var.template_name
  memory        = 8192
  cpus          = 2
  cpu_cores     = 1
  metadata = {
    role    = "compute"
    env     = "demo"
  }
  guest_properties = {
    "hostname"   = "compute2.${var.demo}"
    "user-data" = var.user_data_compute2
  }
  override_template_disk {
    bus_type         = "paravirtual"
    size_in_mb       = "51200"
    bus_number       = 0
    unit_number      = 0
    iops             = 0
  }
  network {
    type               = "org"
    name               = vcd_vapp_org_network.demo.org_network_name
    ip_allocation_mode = "MANUAL"
    ip                 = var.ip_compute2
    is_primary         = true
  }
}

resource "vcd_vapp_vm" "compute3" {
  vapp_name     = vcd_vapp.demo.name
  name          = "compute3.${var.demo}"
  computer_name = "compute3.${var.demo}"
  catalog_name  = var.catalog_name
  template_name = var.template_name
  memory        = 8192
  cpus          = 2
  cpu_cores     = 1
  metadata = {
    role    = "compute"
    env     = "demo"
  }
  guest_properties = {
    "hostname"   = "compute3.${var.demo}"
    "user-data" = var.user_data_compute3
  }
  override_template_disk {
    bus_type         = "paravirtual"
    size_in_mb       = "51200"
    bus_number       = 0
    unit_number      = 0
    iops             = 0
  }
  network {
    type               = "org"
    name               = vcd_vapp_org_network.demo.org_network_name
    ip_allocation_mode = "MANUAL"
    ip                 = var.ip_compute3
    is_primary         = true
  }
}

resource "vcd_vapp_vm" "control" {
  vapp_name     = vcd_vapp.demo.name
  name          = "control.${var.demo}"
  computer_name = "control.${var.demo}"
  catalog_name  = var.catalog_name
  template_name = var.template_name
  memory        = 2048
  cpus          = 1
  cpu_cores     = 1
  metadata = {
    role    = "control"
    env     = "demo"
  }
  guest_properties = {
    "hostname"   = "control.${var.demo}"
    "user-data" = var.user_data_control
  }
  override_template_disk {
    bus_type         = "paravirtual"
    size_in_mb       = "20480"
    bus_number       = 0
    unit_number      = 0
    iops             = 0
  }
  network {
    type               = "org"
    name               = vcd_vapp_org_network.demo.org_network_name
    ip_allocation_mode = "MANUAL"
    ip                 = var.ip_control
    is_primary         = true
  }
}

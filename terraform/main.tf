terraform {
  required_version = ">= 1.5.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.0"
    }
  }
  backend "swift" {
    container         = "terraform-state"
    archive_container = "terraform-state-archive"
    auth_url          = "http://10.0.10.5:5000/v3"
  }
}

provider "openstack" {
  auth_url    = var.auth_url
  region      = var.region
  domain_name = "Default"
}

# --- Variables ---
variable "auth_url" {
  default = "http://10.0.10.5:5000/v3"
}
variable "region" {
  default = "RegionOne"
}
variable "external_network" {
  default = "external"
}
variable "dns_nameservers" {
  default = ["10.0.10.5", "8.8.8.8"]
}

# --- Flavors ---
resource "openstack_compute_flavor_v2" "m1_small" {
  name      = "m1.small"
  ram       = 4096
  vcpus     = 2
  disk      = 20
  is_public = true
}

resource "openstack_compute_flavor_v2" "m1_medium" {
  name      = "m1.medium"
  ram       = 8192
  vcpus     = 4
  disk      = 40
  is_public = true
}

resource "openstack_compute_flavor_v2" "m1_large" {
  name      = "m1.large"
  ram       = 16384
  vcpus     = 8
  disk      = 80
  is_public = true
}

resource "openstack_compute_flavor_v2" "m1_xlarge" {
  name      = "m1.xlarge"
  ram       = 32768
  vcpus     = 16
  disk      = 160
  is_public = true
}

resource "openstack_compute_flavor_v2" "c1_large" {
  name      = "c1.large"
  ram       = 8192
  vcpus     = 8
  disk      = 80
  is_public = true
  extra_specs = {
    "hw:cpu_policy"        = "dedicated"
    "hw:numa_nodes"        = "1"
    "hw:cpu_thread_policy" = "prefer"
  }
}

resource "openstack_compute_flavor_v2" "hpc_large" {
  name      = "hpc.large"
  ram       = 65536
  vcpus     = 32
  disk      = 200
  is_public = false
  extra_specs = {
    "hw:cpu_policy"        = "dedicated"
    "hw:numa_nodes"        = "2"
    "hw:mem_page_size"     = "1GB"
    "hw:cpu_thread_policy" = "isolate"
  }
}

# --- Networks ---
resource "openstack_networking_network_v2" "provider_external" {
  name                  = "external"
  admin_state_up        = true
  external              = true
  shared                = false
  provider_network_type = "flat"
  provider_physical_network = "external"
}

resource "openstack_networking_subnet_v2" "provider_external_subnet" {
  name            = "external-subnet"
  network_id      = openstack_networking_network_v2.provider_external.id
  cidr            = "203.0.113.0/24"
  gateway_ip      = "203.0.113.1"
  ip_version      = 4
  enable_dhcp     = false
  allocation_pool {
    start = "203.0.113.100"
    end   = "203.0.113.250"
  }
}

# --- Tenant Networks (template) ---
resource "openstack_networking_network_v2" "tenant_net" {
  for_each       = toset(["infra", "app", "db"])
  name           = "${each.key}-net"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "tenant_subnet" {
  for_each = {
    infra = "192.168.1.0/24"
    app   = "192.168.2.0/24"
    db    = "192.168.3.0/24"
  }
  name            = "${each.key}-subnet"
  network_id      = openstack_networking_network_v2.tenant_net[each.key].id
  cidr            = each.value
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

# --- Router ---
resource "openstack_networking_router_v2" "main" {
  name                = "main-router"
  admin_state_up      = true
  external_network_id = openstack_networking_network_v2.provider_external.id
}

resource "openstack_networking_router_interface_v2" "router_interfaces" {
  for_each  = openstack_networking_subnet_v2.tenant_subnet
  router_id = openstack_networking_router_v2.main.id
  subnet_id = each.value.id
}

# --- Security Groups ---
resource "openstack_networking_secgroup_v2" "web" {
  name        = "web-servers"
  description = "Allow HTTP/HTTPS and SSH"
}

resource "openstack_networking_secgroup_rule_v2" "web_ssh" {
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "10.0.0.0/8"
}

resource "openstack_networking_secgroup_rule_v2" "web_http" {
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "web_https" {
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
}

# --- Volume Types ---
resource "openstack_blockstorage_volume_type_v3" "standard" {
  name        = "standard-nvme"
  description = "Standard NVMe storage"
  extra_specs = {
    "volume_backend_name" = "LVM_NVMe_AZ1"
  }
}

resource "openstack_blockstorage_volume_type_v3" "encrypted" {
  name        = "encrypted-luks"
  description = "LUKS encrypted NVMe storage"
  extra_specs = {
    "volume_backend_name" = "LVM_NVMe_AZ1"
  }
}

# --- GPU Flavors ---
resource "openstack_compute_flavor_v2" "g1_large" {
  name      = "g1.large"
  ram       = 32768
  vcpus     = 8
  disk      = 100
  is_public = true
  extra_specs = {
    "pci_passthrough:alias"  = "a100:1"
    "hw:cpu_policy"          = "dedicated"
    "hw:numa_nodes"          = "1"
    "hw:mem_page_size"       = "1GB"
    "service_tier"           = "gpu"
  }
}

resource "openstack_compute_flavor_v2" "g1_xlarge" {
  name      = "g1.xlarge"
  ram       = 65536
  vcpus     = 16
  disk      = 200
  is_public = true
  extra_specs = {
    "pci_passthrough:alias"  = "a100:2"
    "hw:cpu_policy"          = "dedicated"
    "hw:numa_nodes"          = "2"
    "hw:mem_page_size"       = "1GB"
    "service_tier"           = "gpu"
  }
}

resource "openstack_compute_flavor_v2" "g1_2xlarge" {
  name      = "g1.2xlarge"
  ram       = 131072
  vcpus     = 32
  disk      = 400
  is_public = false
  extra_specs = {
    "pci_passthrough:alias"  = "a100:4"
    "hw:cpu_policy"          = "dedicated"
    "hw:numa_nodes"          = "2"
    "hw:mem_page_size"       = "1GB"
    "service_tier"           = "gpu"
  }
}

resource "openstack_compute_flavor_v2" "g1_inference" {
  name      = "g1.inference"
  ram       = 16384
  vcpus     = 4
  disk      = 50
  is_public = true
  extra_specs = {
    "pci_passthrough:alias"  = "a100:1"
    "hw:cpu_policy"          = "dedicated"
    "hw:numa_nodes"          = "1"
    "service_tier"           = "gpu"
  }
}

# --- GPU Host Aggregates ---
resource "openstack_compute_aggregate_v2" "gpu_az1" {
  name = "gpu-az1"
  zone = "az1"
  metadata = {
    service_tier = "gpu"
  }
}

resource "openstack_compute_aggregate_v2" "gpu_az2" {
  name = "gpu-az2"
  zone = "az2"
  metadata = {
    service_tier = "gpu"
  }
}

resource "openstack_compute_aggregate_v2" "gpu_az3" {
  name = "gpu-az3"
  zone = "az3"
  metadata = {
    service_tier = "gpu"
  }
}

# --- HSM-Encrypted Volume Type ---
resource "openstack_blockstorage_volume_type_v3" "hsm_encrypted" {
  name        = "hsm-encrypted-luks"
  description = "LUKS encrypted storage with HSM-backed keys (FIPS 140-2 Level 3)"
  extra_specs = {
    "volume_backend_name" = "LVM_NVMe_AZ1"
  }
}

# --- Host Aggregates ---
resource "openstack_compute_aggregate_v2" "az1" {
  name = "az1-general"
  zone = "az1"
  metadata = {
    availability_zone = "az1"
  }
}

resource "openstack_compute_aggregate_v2" "az2" {
  name = "az2-general"
  zone = "az2"
  metadata = {
    availability_zone = "az2"
  }
}

resource "openstack_compute_aggregate_v2" "az3" {
  name = "az3-general"
  zone = "az3"
  metadata = {
    availability_zone = "az3"
  }
}

# --- Outputs ---
output "external_network_id" {
  value = openstack_networking_network_v2.provider_external.id
}

output "router_id" {
  value = openstack_networking_router_v2.main.id
}

output "flavor_ids" {
  value = {
    "m1.small"     = openstack_compute_flavor_v2.m1_small.id
    "m1.medium"    = openstack_compute_flavor_v2.m1_medium.id
    "m1.large"     = openstack_compute_flavor_v2.m1_large.id
    "c1.large"     = openstack_compute_flavor_v2.c1_large.id
    "hpc.large"    = openstack_compute_flavor_v2.hpc_large.id
    "g1.large"     = openstack_compute_flavor_v2.g1_large.id
    "g1.xlarge"    = openstack_compute_flavor_v2.g1_xlarge.id
    "g1.2xlarge"   = openstack_compute_flavor_v2.g1_2xlarge.id
    "g1.inference" = openstack_compute_flavor_v2.g1_inference.id
  }
}

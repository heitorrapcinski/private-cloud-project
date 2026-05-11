# 04 - Design do Compute Plane

## Visão Geral

```
┌─────────────────────────────────────────────────────────────────┐
│                      Compute Plane                               │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   Nova Scheduler                         │    │
│  │  Filters: AZ, Compute, NUMA, ServerGroup, Aggregate     │    │
│  └────────────────────────┬────────────────────────────────┘    │
│                           │                                      │
│       ┌───────────────────┼───────────────────┐                 │
│       │                   │                   │                  │
│  ┌────┴─────┐       ┌────┴─────┐       ┌────┴─────┐           │
│  │  Cell-1  │       │  Cell-2  │       │  Cell-3  │           │
│  │  (AZ1)   │       │  (AZ2)   │       │  (AZ3)   │           │
│  │ 36 nodes │       │ 36 nodes │       │ 36 nodes │           │
│  └──────────┘       └──────────┘       └──────────┘           │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   Ironic (Bare Metal)                     │    │
│  │  Conductor → IPMI/Redfish → Physical Servers             │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Nova Compute (KVM)

### Hypervisor Configuration

```ini
# /etc/nova/nova.conf (compute node)
[DEFAULT]
compute_driver = libvirt.LibvirtDriver
instances_path = /var/lib/nova/instances
resume_guests_state_on_host_boot = true

[libvirt]
virt_type = kvm
cpu_mode = host-passthrough
cpu_models = 
disk_cachemodes = network=writeback,block=none
hw_disk_discard = unmap
live_migration_uri = qemu+ssh://nova@%s/system
live_migration_tunnelled = false
live_migration_completion_timeout = 800
live_migration_permit_auto_converge = true
live_migration_permit_post_copy = true
images_type = qcow2
inject_partition = -2
num_pcie_ports = 28

[compute]
cpu_allocation_ratio = 3.0
ram_allocation_ratio = 1.5
disk_allocation_ratio = 1.5
cpu_dedicated_set = 4-79
cpu_shared_set = 0-3
```

### NUMA Topology

```
┌─────────────────────────────────────────────────┐
│              Compute Node (2-socket)             │
│                                                   │
│  Socket 0 (NUMA Node 0)    Socket 1 (NUMA Node 1)│
│  ┌─────────────────────┐  ┌─────────────────────┐│
│  │ Cores 0-39          │  │ Cores 40-79          ││
│  │ 512 GB RAM          │  │ 512 GB RAM           ││
│  │ NVMe 0 (local)      │  │ NVMe 1 (local)       ││
│  │ NIC port 0,1        │  │ NIC port 2,3         ││
│  └─────────────────────┘  └─────────────────────┘│
│                                                   │
│  Reserved: Cores 0-3 (host OS, emulator threads)  │
│  Pinnable: Cores 4-79 (guest vCPUs)              │
└─────────────────────────────────────────────────┘
```

### Flavor Design

| Flavor | vCPU | RAM | Disk | Properties |
|--------|------|-----|------|------------|
| m1.small | 2 | 4 GB | 20 GB | shared CPU |
| m1.medium | 4 | 8 GB | 40 GB | shared CPU |
| m1.large | 8 | 16 GB | 80 GB | shared CPU |
| m1.xlarge | 16 | 32 GB | 160 GB | shared CPU |
| c1.medium | 4 | 4 GB | 40 GB | dedicated CPU, NUMA |
| c1.large | 8 | 8 GB | 80 GB | dedicated CPU, NUMA |
| c1.xlarge | 16 | 16 GB | 160 GB | dedicated CPU, NUMA |
| r1.large | 4 | 32 GB | 80 GB | high memory |
| r1.xlarge | 8 | 64 GB | 160 GB | high memory |
| hpc.large | 32 | 64 GB | 200 GB | dedicated, NUMA, hugepages |

### Host Aggregates

| Aggregate | Hosts | Metadata | Uso |
|-----------|-------|----------|-----|
| az1-general | compute-az1fd*-* | availability_zone=az1 | General purpose |
| az2-general | compute-az2fd*-* | availability_zone=az2 | General purpose |
| az3-general | compute-az3fd*-* | availability_zone=az3 | General purpose |
| shared-compute | 81 nodes (9/rack) | overcommit=3:1, service_tier=shared | Recursos compartilhados |
| dedicated-compute | 27 nodes (3/rack) | overcommit=1:1, service_tier=dedicated | Recursos dedicados |
| pinned-cpu | selecionados | cpu_policy=dedicated | HPC workloads |
| ssd-ephemeral | todos | disk_type=ssd | NVMe local |

## Ofertas de Overcommitment

O compute plane oferece três tiers de serviço, implementados via Host Aggregates e Placement API.

### Arquitetura de Tiers

```
┌─────────────────────────────────────────────────────────────────┐
│                    Compute Plane - Tiers                          │
│                                                                   │
│  ┌──────────────────────┐  ┌──────────────────┐  ┌───────────┐ │
│  │   SHARED (1:3)       │  │  DEDICATED (1:1) │  │ GPU (1:1) │ │
│  │                      │  │                  │  │           │ │
│  │  81 nodes (75%)      │  │  27 nodes (25%) │  │  9 nodes  │ │
│  │  CPU ratio: 3.0      │  │  CPU ratio: 1.0 │  │  4x GPU   │ │
│  │  RAM ratio: 1.5      │  │  RAM ratio: 1.0 │  │  per node │ │
│  │                      │  │                  │  │           │ │
│  │  Workloads:          │  │  Workloads:      │  │ Workloads:│ │
│  │  - Dev/Test          │  │  - Bancos de dados│  │ - AI/ML   │ │
│  │  - Web servers       │  │  - Apps críticas │  │ - HPC     │ │
│  │  - Microservices     │  │  - Compliance    │  │ - Render  │ │
│  └──────────────────────┘  └──────────────────┘  └───────────┘ │
│                                                                   │
│  Ver docs/10-gpu-compute.md para detalhes do tier GPU            │
└─────────────────────────────────────────────────────────────────┘
```

### Tier 1: Recursos Compartilhados (1:3)

Proporção de overcommitment 1:3 para CPU — cada core físico é compartilhado entre até 3 vCPUs. Ideal para workloads com uso intermitente de CPU.

```ini
# /etc/nova/nova.conf (shared compute nodes)
[compute]
cpu_allocation_ratio = 3.0
ram_allocation_ratio = 1.5
disk_allocation_ratio = 1.5
```

**Capacidade por nó (shared):**

| Recurso | Físico | Disponível (overcommit) |
|---------|--------|------------------------|
| vCPUs | 80 cores | 240 vCPUs |
| RAM | 1 TB | 1.5 TB |
| Disk | 7.68 TB NVMe | 11.52 TB |

**Capacidade total tier shared (81 nodes):**
- 19.440 vCPUs
- 121.5 TB RAM
- 933 TB disk

### Tier 2: Recursos Dedicados (1:1)

Proporção 1:1 — sem overcommitment. Cada vCPU mapeia diretamente para um core físico. Garante performance previsível e isolamento de recursos.

```ini
# /etc/nova/nova.conf (dedicated compute nodes)
[compute]
cpu_allocation_ratio = 1.0
ram_allocation_ratio = 1.0
disk_allocation_ratio = 1.0
```

**Capacidade por nó (dedicated):**

| Recurso | Físico | Disponível |
|---------|--------|-----------|
| vCPUs | 76 (80 - 4 reservados) | 76 vCPUs |
| RAM | 1 TB (- 16 GB host) | ~1008 GB |
| Disk | 7.68 TB NVMe | 7.68 TB |

**Capacidade total tier dedicated (27 nodes):**
- 2.052 vCPUs
- 27 TB RAM
- 207 TB disk

### Configuração via Host Aggregates

```bash
# Criar aggregates
openstack aggregate create --zone az1 shared-az1
openstack aggregate create --zone az1 dedicated-az1

# Definir metadata
openstack aggregate set --property service_tier=shared shared-az1
openstack aggregate set --property service_tier=dedicated dedicated-az1
openstack aggregate set --property cpu_allocation_ratio=3.0 shared-az1
openstack aggregate set --property cpu_allocation_ratio=1.0 dedicated-az1
openstack aggregate set --property ram_allocation_ratio=1.5 shared-az1
openstack aggregate set --property ram_allocation_ratio=1.0 dedicated-az1

# Adicionar hosts
openstack aggregate add host shared-az1 compute-az1fd1-01
# ... (9 nodes por rack, 27 por AZ para shared)
openstack aggregate add host dedicated-az1 compute-az1fd1-10
# ... (3 nodes por rack, 9 por AZ para dedicated)
```

### Flavors por Tier

#### Shared Flavors (overcommit 1:3)

| Flavor | vCPU | RAM | Disk | Extra Specs |
|--------|------|-----|------|-------------|
| s1.small | 2 | 4 GB | 20 GB | service_tier=shared |
| s1.medium | 4 | 8 GB | 40 GB | service_tier=shared |
| s1.large | 8 | 16 GB | 80 GB | service_tier=shared |
| s1.xlarge | 16 | 32 GB | 160 GB | service_tier=shared |
| s1.2xlarge | 32 | 64 GB | 320 GB | service_tier=shared |

#### Dedicated Flavors (overcommit 1:1)

| Flavor | vCPU | RAM | Disk | Extra Specs |
|--------|------|-----|------|-------------|
| d1.small | 2 | 4 GB | 20 GB | service_tier=dedicated, hw:cpu_policy=dedicated |
| d1.medium | 4 | 8 GB | 40 GB | service_tier=dedicated, hw:cpu_policy=dedicated |
| d1.large | 8 | 16 GB | 80 GB | service_tier=dedicated, hw:cpu_policy=dedicated |
| d1.xlarge | 16 | 32 GB | 160 GB | service_tier=dedicated, hw:cpu_policy=dedicated |
| d1.2xlarge | 32 | 64 GB | 320 GB | service_tier=dedicated, hw:cpu_policy=dedicated, hw:numa_nodes=2 |

### Scheduler Filters

```ini
# /etc/nova/nova.conf (controller)
[filter_scheduler]
enabled_filters = AvailabilityZoneFilter,ComputeFilter,ComputeCapabilitiesFilter,ImagePropertiesFilter,ServerGroupAntiAffinityFilter,ServerGroupAffinityFilter,AggregateInstanceExtraSpecsFilter,NUMATopologyFilter,AggregateMultiTenancyIsolation
available_filters = nova.scheduler.filters.all_filters

# AggregateInstanceExtraSpecsFilter garante que flavors com
# service_tier=shared só agendam em hosts do aggregate shared
```

### Distribuição de Hosts por Rack

```
┌─────────────────────────────────────────────────────────────┐
│  Rack (12 compute nodes)                                     │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Shared (9 nodes)                                    │    │
│  │  compute-{az}{fd}-01 a 09                            │    │
│  │  CPU 3:1 | RAM 1.5:1 | Disk 1.5:1                   │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Dedicated (3 nodes)                                  │    │
│  │  compute-{az}{fd}-10 a 12                            │    │
│  │  CPU 1:1 | RAM 1:1 | Disk 1:1                       │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Monitoramento e SLA por Tier

| Métrica | Shared | Dedicated |
|---------|--------|-----------|
| SLA Disponibilidade | 99.9% | 99.99% |
| CPU Steal máximo | 15% | 0% (garantido) |
| Latência de rede (P99) | < 2ms | < 0.5ms |
| IOPS garantido | Best-effort | Reservado via QoS |
| Live Migration | Permitida | Janela programada |
| Noisy Neighbor | Possível | Isolado |

## Live Migration

### Configuração

```ini
[libvirt]
live_migration_uri = qemu+ssh://nova@%s/system
live_migration_tunnelled = false
live_migration_inbound_addr = ${my_ip}
live_migration_completion_timeout = 800
live_migration_timeout_action = force_complete
live_migration_permit_auto_converge = true
live_migration_permit_post_copy = true
live_migration_bandwidth = 0  # unlimited, use QoS no switch

[libvirt]
# Para migração entre AZs (cross-cell não suportado nativamente)
# Migração apenas dentro da mesma Cell/AZ
```

### Restrições
- Live migration apenas dentro da mesma AZ/Cell
- Cross-AZ requer cold migration (evacuate)
- Bandwidth limitada via QoS no switch (10 Gbps por migração)

## Ironic (Bare Metal)

### Arquitetura

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ ironic-api   │     │ironic-conduct│     │  ironic-insp │
│  (ctrl-01)   │     │  (ctrl-01)   │     │  (ctrl-01)   │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                     │                     │
       │              ┌──────┴───────┐             │
       │              │   Redfish/   │             │
       │              │    IPMI      │             │
       │              └──────┬───────┘             │
       │                     │                     │
       │              ┌──────┴───────┐             │
       │              │  Bare Metal  │             │
       │              │   Servers    │             │
       │              └──────────────┘             │
       │                                           │
       └───────────────────────────────────────────┘
                    PXE/HTTP Boot
```

### Deploy Drivers

| Driver | Interface | Uso |
|--------|-----------|-----|
| ipmi | power, management | Servidores legados compatíveis com IPMI 2.0 |
| redfish | power, management, bios | Servidores com BMC compatível com Redfish |

### Provisioning Network

```ini
[neutron]
cleaning_network = ironic-cleaning-net
provisioning_network = ironic-provision-net
inspection_network = ironic-inspect-net

[conductor]
automated_clean = true
deploy_kernel = file:///httpboot/ironic-agent.kernel
deploy_ramdisk = file:///httpboot/ironic-agent.initramfs

[pxe]
tftp_server = 10.0.10.11
tftp_root = /tftpboot
http_url = http://10.0.10.11:8080
http_root = /httpboot
```

### Node Enrollment

```bash
openstack baremetal node create \
  --driver redfish \
  --driver-info redfish_address=https://172.16.0.101/redfish/v1 \
  --driver-info redfish_username=admin \
  --driver-info redfish_password=SECURE \
  --driver-info redfish_system_id=/redfish/v1/Systems/System.Embedded.1 \
  --property capabilities='boot_mode:uefi' \
  --resource-class baremetal.large \
  --name bm-az1fd1-01
```

## Placement Service

### Resource Classes

| Resource Class | Inventário (Shared) | Inventário (Dedicated) | Uso |
|----------------|--------------------|-----------------------|-----|
| VCPU | 240 per host (3:1) | 76 per host (1:1) | Virtual CPUs |
| PCPU | 76 per host | 76 per host | Dedicated CPUs |
| MEMORY_MB | 1572864 per host (1.5:1) | 1032192 per host (1:1) | RAM |
| DISK_GB | 11520 per host (1.5:1) | 7680 per host (1:1) | Ephemeral |
| CUSTOM_BAREMETAL_LARGE | 1 per BM node | 1 per BM node | Bare metal |

### Traits

```
COMPUTE_STATUS_DISABLED
HW_CPU_X86_AVX2
HW_CPU_X86_AVX512F
HW_NIC_SRIOV
CUSTOM_NUMA_AWARE
CUSTOM_SSD_EPHEMERAL
```

## Compute Node Lifecycle

### Day 0: Provisioning

```
1. PXE boot via Ironic/MAAS
2. Ubuntu 24.04 LTS (Noble) base install
3. Ansible post-config (networking, packages)
4. Kolla-Ansible deploy (nova-compute, neutron-ovn-agent)
5. Register in Nova cell
6. Verify via `openstack compute service list`
```

### Day 2: Maintenance

```bash
# Disable scheduling
openstack compute service set --disable --disable-reason "maintenance" compute-az1fd1-01 nova-compute

# Live migrate all VMs
nova host-evacuate-live compute-az1fd1-01

# Perform maintenance
# ...

# Re-enable
openstack compute service set --enable compute-az1fd1-01 nova-compute
```

### Scale-Out

```
1. Rack new server
2. Cable (2x 25GbE to Leaf-A/B, 1x 1GbE to OOB)
3. Configure BMC (IPMI/Redfish)
4. Add to Ansible inventory
5. Run playbook: ansible-playbook -l new_host site.yml
6. Verify: openstack hypervisor show <hostname>
```

## Performance Tuning

### Kernel Parameters (compute nodes)

```ini
# /etc/sysctl.d/99-openstack-compute.conf
vm.swappiness = 1
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
kernel.pid_max = 4194304
fs.file-max = 1048576
fs.inotify.max_user_instances = 8192
```

### Hugepages (para flavors HPC)

```ini
# /etc/default/grub
GRUB_CMDLINE_LINUX="hugepagesz=1G hugepages=512 default_hugepagesz=1G intel_iommu=on iommu=pt"
```

### CPU Governor

```bash
# Performance governor para todos os cores
cpupower frequency-set -g performance
```

## Decisões Arquiteturais

1. **host-passthrough CPU**: Máxima performance, expõe todas as features do host
2. **Cells por AZ**: Isolamento de falha, DB/MQ independentes por AZ
3. **Dois tiers de overcommit**: Shared (1:3) para workloads gerais, Dedicated (1:1) para serviços críticos
4. **75/25 split**: 75% da frota para shared maximiza densidade, 25% dedicado atende SLAs premium
5. **Dedicated CPU set**: Cores 0-3 reservados para host OS, evita contention
6. **NVMe ephemeral**: Performance de disco local para VMs sem Cinder
7. **Live migration auto-converge**: Garante conclusão mesmo com VMs write-intensive
8. **Ironic Redfish**: API moderna, suporte a BIOS config, virtual media boot
9. **AggregateInstanceExtraSpecsFilter**: Garante isolamento entre tiers via scheduler
10. **GPU tier (PCI passthrough)**: Aceleradores GPU compute-class via Cyborg/Nova, sem overcommit, NUMA-aware (ver docs/10-gpu-compute.md)

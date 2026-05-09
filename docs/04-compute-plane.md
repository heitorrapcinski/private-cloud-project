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
cpu_allocation_ratio = 4.0
ram_allocation_ratio = 1.5
disk_allocation_ratio = 1.0
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
| pinned-cpu | selecionados | cpu_policy=dedicated | HPC workloads |
| ssd-ephemeral | todos | disk_type=ssd | NVMe local |

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
| ipmi | power, management | Legacy servers |
| redfish | power, management, bios | Dell iDRAC 9+ |
| idrac-redfish | vendor-specific | Dell PowerEdge |

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
  --driver idrac-redfish \
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

| Resource Class | Inventário | Uso |
|----------------|-----------|-----|
| VCPU | 160 per host (4:1) | Virtual CPUs |
| PCPU | 76 per host | Dedicated CPUs |
| MEMORY_MB | 1048576 per host | RAM |
| DISK_GB | 7000 per host | Ephemeral |
| CUSTOM_BAREMETAL_LARGE | 1 per BM node | Bare metal |

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
2. Ubuntu 22.04 LTS base install
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
3. Configure IPMI/iDRAC
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
3. **4:1 CPU overcommit**: Balanceamento entre density e performance para workloads gerais
4. **Dedicated CPU set**: Cores 0-3 reservados para host OS, evita contention
5. **NVMe ephemeral**: Performance de disco local para VMs sem Cinder
6. **Live migration auto-converge**: Garante conclusão mesmo com VMs write-intensive
7. **Ironic Redfish**: API moderna, suporte a BIOS config, virtual media boot

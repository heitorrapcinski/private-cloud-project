# 10 - GPU Compute Plane

## Visão Geral

```
┌─────────────────────────────────────────────────────────────────┐
│                    GPU Compute Plane                              │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Nova Scheduler + Placement API              │    │
│  │  Filters: PciPassthrough, AZ, NUMA, Aggregate           │    │
│  │  Resource Class: CUSTOM_GPU_NVIDIA_A100                  │    │
│  └────────────────────────┬────────────────────────────────┘    │
│                           │                                      │
│  ┌────────────────────────┴────────────────────────────────┐    │
│  │                   Cyborg Service                         │    │
│  │  Device Profiles → Accelerator Requests (ARQs)          │    │
│  │  Driver: nvidia-gpu                                      │    │
│  └────────────────────────┬────────────────────────────────┘    │
│                           │                                      │
│       ┌───────────────────┼───────────────────┐                 │
│       │                   │                   │                  │
│  ┌────┴─────┐       ┌────┴─────┐       ┌────┴─────┐           │
│  │  AZ1     │       │  AZ2     │       │  AZ3     │           │
│  │  3 GPU   │       │  3 GPU   │       │  3 GPU   │           │
│  │  nodes   │       │  nodes   │       │  nodes   │           │
│  └──────────┘       └──────────┘       └──────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

## Hardware GPU Nodes (9 unidades — 3 por AZ)

| Componente | Especificação |
|------------|---------------|
| Servidor | Dell PowerEdge R750xa (2U) |
| CPU | 2x Intel Xeon Platinum 8380 (40C/80T) |
| RAM | 1 TB DDR4-3200 ECC RDIMM |
| GPU | 4x NVIDIA A100 80GB SXM4 (NVLink) |
| Boot | 2x 480GB SSD SATA (RAID1) |
| Local Storage | 2x 3.84TB NVMe U.2 |
| NIC | 2x Mellanox ConnectX-6 25GbE (4 ports) |
| IPMI | iDRAC 9 Enterprise |
| PSU | 2x 2400W Platinum (redundante) |
| Cooling | Direct liquid cooling (GPU) + air (CPU) |

### Distribuição por AZ

| Nó | AZ | FD | Rack | GPUs |
|----|----|----|------|------|
| gpu-az1fd1-01 | AZ1 | FD1 | R1 | 4x A100 80GB |
| gpu-az1fd2-01 | AZ1 | FD2 | R2 | 4x A100 80GB |
| gpu-az1fd3-01 | AZ1 | FD3 | R3 | 4x A100 80GB |
| gpu-az2fd1-01 | AZ2 | FD1 | R4 | 4x A100 80GB |
| gpu-az2fd2-01 | AZ2 | FD2 | R5 | 4x A100 80GB |
| gpu-az2fd3-01 | AZ2 | FD3 | R6 | 4x A100 80GB |
| gpu-az3fd1-01 | AZ3 | FD1 | R7 | 4x A100 80GB |
| gpu-az3fd2-01 | AZ3 | FD2 | R8 | 4x A100 80GB |
| gpu-az3fd3-01 | AZ3 | FD3 | R9 | 4x A100 80GB |

**Total:** 36 GPUs NVIDIA A100 80GB (2.880 GB VRAM)

## Integração OpenStack

### Nova PCI Passthrough

```ini
# /etc/nova/nova.conf (GPU compute nodes)
[pci]
alias = {"vendor_id": "10de", "product_id": "20b2", "device_type": "type-PCI", "name": "a100", "numa_policy": "preferred"}
passthrough_whitelist = [{"vendor_id": "10de", "product_id": "20b2"}]

[compute]
cpu_allocation_ratio = 1.0
ram_allocation_ratio = 1.0
```

```ini
# /etc/nova/nova.conf (controller)
[pci]
alias = {"vendor_id": "10de", "product_id": "20b2", "device_type": "type-PCI", "name": "a100", "numa_policy": "preferred"}

[filter_scheduler]
enabled_filters = AvailabilityZoneFilter,ComputeFilter,ComputeCapabilitiesFilter,ImagePropertiesFilter,PciPassthroughFilter,NUMATopologyFilter,AggregateInstanceExtraSpecsFilter
available_filters = nova.scheduler.filters.all_filters
```

### Cyborg (Accelerator Lifecycle Manager)

```ini
# /etc/cyborg/cyborg.conf
[DEFAULT]
transport_url = rabbit://openstack:PASS@mq-01:5672,mq-02:5672,mq-03:5672/
auth_strategy = keystone

[database]
connection = mysql+pymysql://cyborg:PASS@10.0.200.5/cyborg

[keystone_authtoken]
www_authenticate_uri = http://10.0.10.5:5000
auth_url = http://10.0.10.5:5000
auth_type = password
project_name = service
username = cyborg
password = CYBORG_PASS

[nova]
auth_url = http://10.0.10.5:5000
auth_type = password
project_name = service
username = nova
password = NOVA_PASS
```

### Device Profiles (Cyborg)

```json
[
  {
    "name": "a100-1gpu",
    "groups": [{"resources:CUSTOM_GPU_NVIDIA_A100": "1"}]
  },
  {
    "name": "a100-2gpu",
    "groups": [{"resources:CUSTOM_GPU_NVIDIA_A100": "2"}]
  },
  {
    "name": "a100-4gpu",
    "groups": [{"resources:CUSTOM_GPU_NVIDIA_A100": "4"}]
  }
]
```

## GPU Flavors

| Flavor | vCPU | RAM | Disk | GPUs | Extra Specs |
|--------|------|-----|------|------|-------------|
| g1.large | 8 | 32 GB | 100 GB | 1x A100 | dedicated CPU, NUMA |
| g1.xlarge | 16 | 64 GB | 200 GB | 2x A100 | dedicated CPU, NUMA |
| g1.2xlarge | 32 | 128 GB | 400 GB | 4x A100 | dedicated CPU, NUMA, NVLink |
| g1.inference | 4 | 16 GB | 50 GB | 1x A100 | dedicated CPU, inference workloads |

### Extra Specs dos Flavors

```bash
# g1.large
openstack flavor set g1.large \
  --property "pci_passthrough:alias"="a100:1" \
  --property "hw:cpu_policy"="dedicated" \
  --property "hw:numa_nodes"="1" \
  --property "hw:mem_page_size"="1GB" \
  --property "service_tier"="gpu"

# g1.2xlarge (full node — 4 GPUs com NVLink)
openstack flavor set g1.2xlarge \
  --property "pci_passthrough:alias"="a100:4" \
  --property "hw:cpu_policy"="dedicated" \
  --property "hw:numa_nodes"="2" \
  --property "hw:mem_page_size"="1GB" \
  --property "service_tier"="gpu"
```

## Host Aggregate

```bash
# Criar aggregate GPU
openstack aggregate create --zone az1 gpu-az1
openstack aggregate create --zone az2 gpu-az2
openstack aggregate create --zone az3 gpu-az3

# Metadata
openstack aggregate set --property service_tier=gpu gpu-az1
openstack aggregate set --property service_tier=gpu gpu-az2
openstack aggregate set --property service_tier=gpu gpu-az3

# Adicionar hosts
openstack aggregate add host gpu-az1 gpu-az1fd1-01
openstack aggregate add host gpu-az1 gpu-az1fd2-01
openstack aggregate add host gpu-az1 gpu-az1fd3-01
```

## Placement API — Resource Classes

| Resource Class | Inventário por Host | Total (9 nodes) |
|----------------|--------------------:|----------------:|
| CUSTOM_GPU_NVIDIA_A100 | 4 | 36 |
| PCPU | 76 | 684 |
| MEMORY_MB | 1032192 | ~9 TB |

### Traits

```
CUSTOM_GPU_NVIDIA_A100_80GB
CUSTOM_GPU_NVLINK
CUSTOM_GPU_MIG_CAPABLE
HW_GPU_API_CUDA
HW_GPU_API_VULKAN
```

## NVIDIA Driver & Runtime

```ini
# /etc/nova/nova.conf (GPU nodes)
[devices]
enabled_vgpu_types =

# PCI passthrough (full GPU) — não usa vGPU
```

### Preparação do Host

```bash
# Instalar NVIDIA driver (headless, sem X11)
apt install nvidia-driver-535-server nvidia-utils-535-server

# Verificar GPUs
nvidia-smi

# Habilitar IOMMU (GRUB)
GRUB_CMDLINE_LINUX="intel_iommu=on iommu=pt hugepagesz=1G hugepages=512"

# Verificar IOMMU groups
find /sys/kernel/iommu_groups/ -type l | sort -V
```

## Monitoramento GPU

| Métrica | Fonte | Alerta |
|---------|-------|--------|
| GPU Utilization | nvidia_gpu_exporter | > 95% sustained 10min |
| GPU Memory Used | nvidia_gpu_exporter | > 90% |
| GPU Temperature | nvidia_gpu_exporter | > 83°C |
| ECC Errors | nvidia_gpu_exporter | > 0 uncorrectable |
| Power Draw | nvidia_gpu_exporter | > 350W per GPU |
| NVLink Bandwidth | nvidia_gpu_exporter | < 50% expected |

### Prometheus Exporter

```yaml
# prometheus/gpu-targets.yml
- targets:
  - gpu-az1fd1-01:9835
  - gpu-az1fd2-01:9835
  - gpu-az1fd3-01:9835
  - gpu-az2fd1-01:9835
  - gpu-az2fd2-01:9835
  - gpu-az2fd3-01:9835
  - gpu-az3fd1-01:9835
  - gpu-az3fd2-01:9835
  - gpu-az3fd3-01:9835
```

## Capacidade e SLA

| Métrica | Valor |
|---------|-------|
| Total GPUs | 36x A100 80GB |
| VRAM Total | 2.880 GB |
| FP64 (por GPU) | 9.7 TFLOPS |
| FP32 (por GPU) | 19.5 TFLOPS |
| TF32 (por GPU) | 156 TFLOPS |
| NVLink Bandwidth | 600 GB/s (bidirecional) |
| SLA Disponibilidade | 99.9% |
| Overcommit | 1:1 (sem overcommit) |

## Decisões Arquiteturais

1. **PCI Passthrough (não vGPU)**: Performance máxima, acesso direto ao hardware, sem overhead de virtualização
2. **A100 80GB SXM4**: Suporte a NVLink para multi-GPU, MIG-capable para futura partição
3. **1 GPU node por FD**: Distribui risco — falha de rack afeta no máximo 1 GPU node por AZ
4. **Cyborg + Nova**: Cyborg gerencia lifecycle dos aceleradores, Nova faz scheduling via Placement
5. **Dedicated CPU (1:1)**: Workloads GPU são CPU-bound no preprocessing — sem overcommit
6. **Hugepages 1GB**: Reduz TLB misses para transferências GPU↔RAM
7. **Liquid cooling**: A100 SXM4 dissipa 400W — requer cooling dedicado
8. **NUMA-aware**: GPU afinidade com NUMA node local para minimizar latência PCIe

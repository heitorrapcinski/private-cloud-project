# 10 - GPU Compute Plane

## Visão Geral

```
┌─────────────────────────────────────────────────────────────────┐
│                    GPU Compute Plane                              │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Nova Scheduler + Placement API              │    │
│  │  Filters: PciPassthrough, AZ, NUMA, Aggregate           │    │
│  │  Resource Class: CUSTOM_GPU_COMPUTE_80GB                 │    │
│  └────────────────────────┬────────────────────────────────┘    │
│                           │                                      │
│  ┌────────────────────────┴────────────────────────────────┐    │
│  │                   Cyborg Service                         │    │
│  │  Device Profiles → Accelerator Requests (ARQs)          │    │
│  │  Driver: vendor-gpu (PCI passthrough)                    │    │
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

## Hardware GPU Nodes — Requisitos Técnicos (9 unidades — 3 por AZ)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 2U, dual-socket, com suporte a aceleradores PCIe Gen4 x16 e SXM |
| CPU | 2x processadores x86_64, 40 cores / 80 threads cada, suporte a VT-d/IOMMU, AVX-512 |
| RAM | 1 TB DDR4-3200 ECC RDIMM |
| GPU | 4x aceleradores compute-class com as seguintes características: |
|     | &nbsp;&nbsp;• 80 GB HBM2e VRAM por acelerador |
|     | &nbsp;&nbsp;• Interconexão NVLink ≥ 600 GB/s bidirecional entre GPUs do mesmo nó |
|     | &nbsp;&nbsp;• Form factor SXM4 (ou equivalente com suporte a NVLink) |
|     | &nbsp;&nbsp;• Suporte a particionamento MIG (Multi-Instance GPU) |
|     | &nbsp;&nbsp;• FP64 ≥ 9 TFLOPS, FP32 ≥ 19 TFLOPS, TF32 ≥ 150 TFLOPS |
|     | &nbsp;&nbsp;• API CUDA compatível (runtime + driver) |
|     | &nbsp;&nbsp;• TDP ≥ 400W por GPU |
| Boot | 2x SSD SATA 480 GB em RAID1 |
| Local Storage | 2x NVMe U.2 3.84 TB |
| NIC | 2x portas 25GbE com RDMA, SR-IOV |
| Gerenciamento OOB | BMC com IPMI 2.0 e Redfish |
| PSU | 2x 2400W Platinum, hot-swap, feeds redundantes |
| Cooling | Direct liquid cooling para GPUs + air cooling para CPUs |

### Distribuição por AZ

| Nó | AZ | FD | Rack | GPUs |
|----|----|----|------|------|
| gpu-az1fd1-01 | AZ1 | FD1 | R1 | 4x 80GB |
| gpu-az1fd2-01 | AZ1 | FD2 | R2 | 4x 80GB |
| gpu-az1fd3-01 | AZ1 | FD3 | R3 | 4x 80GB |
| gpu-az2fd1-01 | AZ2 | FD1 | R4 | 4x 80GB |
| gpu-az2fd2-01 | AZ2 | FD2 | R5 | 4x 80GB |
| gpu-az2fd3-01 | AZ2 | FD3 | R6 | 4x 80GB |
| gpu-az3fd1-01 | AZ3 | FD1 | R7 | 4x 80GB |
| gpu-az3fd2-01 | AZ3 | FD2 | R8 | 4x 80GB |
| gpu-az3fd3-01 | AZ3 | FD3 | R9 | 4x 80GB |

**Total:** 36 GPUs compute-class (2.880 GB VRAM agregada)

## Integração OpenStack

### Nova PCI Passthrough

> Os vendor_id e product_id devem refletir os aceleradores efetivamente instalados. Os valores abaixo são placeholders.

```ini
# /etc/nova/nova.conf (GPU compute nodes)
[pci]
alias = {"vendor_id": "VVVV", "product_id": "PPPP", "device_type": "type-PCI", "name": "gpu80", "numa_policy": "preferred"}
passthrough_whitelist = [{"vendor_id": "VVVV", "product_id": "PPPP"}]

[compute]
cpu_allocation_ratio = 1.0
ram_allocation_ratio = 1.0
```

```ini
# /etc/nova/nova.conf (controller)
[pci]
alias = {"vendor_id": "VVVV", "product_id": "PPPP", "device_type": "type-PCI", "name": "gpu80", "numa_policy": "preferred"}

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
    "name": "gpu80-1",
    "groups": [{"resources:CUSTOM_GPU_COMPUTE_80GB": "1"}]
  },
  {
    "name": "gpu80-2",
    "groups": [{"resources:CUSTOM_GPU_COMPUTE_80GB": "2"}]
  },
  {
    "name": "gpu80-4",
    "groups": [{"resources:CUSTOM_GPU_COMPUTE_80GB": "4"}]
  }
]
```

## GPU Flavors

| Flavor | vCPU | RAM | Disk | GPUs | Extra Specs |
|--------|------|-----|------|------|-------------|
| g1.large | 8 | 32 GB | 100 GB | 1x 80GB | dedicated CPU, NUMA |
| g1.xlarge | 16 | 64 GB | 200 GB | 2x 80GB | dedicated CPU, NUMA |
| g1.2xlarge | 32 | 128 GB | 400 GB | 4x 80GB | dedicated CPU, NUMA, NVLink |
| g1.inference | 4 | 16 GB | 50 GB | 1x 80GB | dedicated CPU, inference workloads |

### Extra Specs dos Flavors

```bash
# g1.large
openstack flavor set g1.large \
  --property "pci_passthrough:alias"="gpu80:1" \
  --property "hw:cpu_policy"="dedicated" \
  --property "hw:numa_nodes"="1" \
  --property "hw:mem_page_size"="1GB" \
  --property "service_tier"="gpu"

# g1.2xlarge (full node — 4 GPUs com NVLink)
openstack flavor set g1.2xlarge \
  --property "pci_passthrough:alias"="gpu80:4" \
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
| CUSTOM_GPU_COMPUTE_80GB | 4 | 36 |
| PCPU | 76 | 684 |
| MEMORY_MB | 1032192 | ~9 TB |

### Traits

```
CUSTOM_GPU_COMPUTE_80GB_HBM2E
CUSTOM_GPU_NVLINK
CUSTOM_GPU_MIG_CAPABLE
HW_GPU_API_CUDA
HW_GPU_API_VULKAN
```

## GPU Driver & Runtime

```ini
# /etc/nova/nova.conf (GPU nodes)
[devices]
enabled_vgpu_types =

# PCI passthrough (full GPU) — não usa vGPU
```

### Preparação do Host

```bash
# Instalar driver de GPU compatível com o hardware (headless, sem X11)
# O pacote específico depende do fornecedor do acelerador instalado
apt install <gpu-driver-server-package> <gpu-utils-package>

# Verificar GPUs via ferramenta do fornecedor
<gpu-smi-tool>

# Habilitar IOMMU (GRUB)
GRUB_CMDLINE_LINUX="intel_iommu=on iommu=pt hugepagesz=1G hugepages=512"

# Verificar IOMMU groups
find /sys/kernel/iommu_groups/ -type l | sort -V
```

## Monitoramento GPU

| Métrica | Fonte | Alerta |
|---------|-------|--------|
| GPU Utilization | gpu_exporter | > 95% sustained 10min |
| GPU Memory Used | gpu_exporter | > 90% |
| GPU Temperature | gpu_exporter | > 83°C |
| ECC Errors | gpu_exporter | > 0 uncorrectable |
| Power Draw | gpu_exporter | > 350W per GPU |
| NVLink Bandwidth | gpu_exporter | < 50% expected |

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
| Total GPUs | 36x compute-class 80GB |
| VRAM Total | 2.880 GB |
| FP64 (por GPU) | ≥ 9 TFLOPS |
| FP32 (por GPU) | ≥ 19 TFLOPS |
| TF32 (por GPU) | ≥ 150 TFLOPS |
| NVLink Bandwidth | ≥ 600 GB/s (bidirecional) |
| SLA Disponibilidade | 99.9% |
| Overcommit | 1:1 (sem overcommit) |

## Decisões Arquiteturais

1. **PCI Passthrough (não vGPU)**: Performance máxima, acesso direto ao hardware, sem overhead de virtualização
2. **GPU 80GB com NVLink**: Suporte a workloads multi-GPU com interconexão de alta largura de banda; particionamento MIG habilita futura subdivisão
3. **1 GPU node por FD**: Distribui risco — falha de rack afeta no máximo 1 GPU node por AZ
4. **Cyborg + Nova**: Cyborg gerencia lifecycle dos aceleradores, Nova faz scheduling via Placement
5. **Dedicated CPU (1:1)**: Workloads GPU são CPU-bound no preprocessing — sem overcommit
6. **Hugepages 1GB**: Reduz TLB misses para transferências GPU↔RAM
7. **Liquid cooling**: Aceleradores SXM dissipam ≥ 400W — requer cooling dedicado
8. **NUMA-aware**: GPU afinidade com NUMA node local para minimizar latência PCIe
9. **Requisitos agnósticos de marca**: Especificação baseada em capabilities (HBM2e, NVLink, CUDA, MIG) permite múltiplos fornecedores compatíveis

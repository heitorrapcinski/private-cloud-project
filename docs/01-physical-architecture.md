# 01 - Arquitetura Física

## Visão Geral

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         REGIÃO: RegionOne                                    │
│                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│  │       AZ1       │  │       AZ2       │  │       AZ3       │            │
│  │                 │  │                 │  │                 │            │
│  │ ┌───┐┌───┐┌───┐│  │ ┌───┐┌───┐┌───┐│  │ ┌───┐┌───┐┌───┐│            │
│  │ │FD1││FD2││FD3││  │ │FD1││FD2││FD3││  │ │FD1││FD2││FD3││            │
│  │ │R1 ││R2 ││R3 ││  │ │R4 ││R5 ││R6 ││  │ │R7 ││R8 ││R9 ││            │
│  │ └───┘└───┘└───┘│  │ └───┘└───┘└───┘│  │ └───┘└───┘└───┘│            │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘            │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Topologia por Rack

Cada rack (42U) segue um layout lógico padronizado. Existem três variantes:

- **Rack FD1** (R1, R4, R7 — um por AZ): aloja control plane, Cinder, HSM, GPU, network node.
- **Rack FD2** (R2, R5, R8 — um por AZ): aloja um dos 3 spines do fabric (core network), além de compute, GPU, Swift e network node.
- **Rack FD3** (R3, R6, R9 — um por AZ): rack padrão de compute/GPU/Swift/network node (sem spine nem HSM).

### Rack FD3 (R3, R6, R9) — Rack Padrão

| Posição U | Equipamento | Função |
|-----------|-------------|--------|
| U1-U2 | PDU A + PDU B | Energia redundante (feeds distintos) |
| U3 | Patch Panel Fibra | Uplinks Spine |
| U4 | ToR Switch A (Leaf) | Rede primária |
| U5 | ToR Switch B (Leaf) | Rede redundante |
| U6 | Management Switch | OOB/IPMI |
| U7-U30 | Compute Nodes (12x 2U) | KVM Hypervisors |
| U31-U34 | GPU Compute Node (1x 4U) | Aceleração GPU |
| U35-U38 | Swift Storage Nodes (2x 2U) | Object Storage |
| U39 | Network Node (1x 1U) | OVN Gateway |
| U40-U42 | Cable Management / Reserva | Organização e expansão |

### Rack FD2 (R2, R5, R8) — Aloja Spine (1 por AZ)

O spine da AZ ocupa o rack FD2, consumindo espaço que antes estava destinado a compute. Cada rack FD2 perde 2 nós de compute em relação ao rack FD3 para acomodar o spine, o patch panel do fabric e a ventilação dedicada.

| Posição U | Equipamento | Função |
|-----------|-------------|--------|
| U1-U2 | PDU A + PDU B | Energia redundante (feeds distintos) |
| U3 | Patch Panel Fibra | Uplinks de leaves locais |
| U4 | ToR Switch A (Leaf) | Rede primária |
| U5 | ToR Switch B (Leaf) | Rede redundante |
| U6 | Management Switch | OOB/IPMI |
| U7-U8 | Spine Switch (1x 2U) | Core fabric (1 spine por AZ) |
| U9-U10 | Spine Patch Panel (MPO/LC) | Uplinks spine ↔ 18 leaves + mesh inter-spine |
| U11 | Reserva de cooling | Headroom térmico do spine |
| U12-U31 | Compute Nodes (10x 2U) | KVM Hypervisors |
| U32-U35 | GPU Compute Node (1x 4U) | Aceleração GPU |
| U36-U39 | Swift Storage Nodes (2x 2U) | Object Storage |
| U40 | Network Node (1x 1U) | OVN Gateway |
| U41-U42 | Cable Management | Organização |

### Rack FD1 (R1, R4, R7) — Control Plane + Cinder + HSM

| Posição U | Equipamento | Função |
|-----------|-------------|--------|
| U1-U2 | PDU A + PDU B | Energia redundante |
| U3 | Patch Panel Fibra | Uplinks Spine |
| U4 | ToR Switch A (Leaf) | Rede primária |
| U5 | ToR Switch B (Leaf) | Rede redundante |
| U6 | Management Switch | OOB/IPMI |
| U7-U10 | Control Plane Nodes (4x 1U) | Controller + DB + MQ + LB |
| U11-U12 | Cinder Storage Node (1x 2U) | Block Storage |
| U13-U36 | Compute Nodes (12x 2U) | KVM Hypervisors |
| U37-U40 | GPU Compute Node (1x 4U) | Aceleração GPU |
| U41 | HSM Appliance (1x 1U) | Gestão de chaves criptográficas |
| U42 | Network Node (1x 1U) | OVN Gateway |

> **Nota FD1:** Com o GPU node em 4U, os 42U são totalmente utilizados. Gerenciamento de cabos
> é feito via painéis verticais laterais do rack (sem consumo de U).

## Distribuição de Roles por AZ

### Control Plane (distribuído entre 3 AZs)

| Nó | AZ | FD | Rack | Função |
|----|----|----|------|--------|
| ctrl-01 | AZ1 | FD1 | R1 | Keystone, Glance, Nova-API, Neutron-Server, Horizon |
| ctrl-02 | AZ2 | FD1 | R4 | Keystone, Glance, Nova-API, Neutron-Server, Horizon |
| ctrl-03 | AZ3 | FD1 | R7 | Keystone, Glance, Nova-API, Neutron-Server, Horizon |
| db-01 | AZ1 | FD1 | R1 | MariaDB Galera (Primary) |
| db-02 | AZ2 | FD1 | R4 | MariaDB Galera (Secondary) |
| db-03 | AZ3 | FD1 | R7 | MariaDB Galera (Secondary) |
| mq-01 | AZ1 | FD1 | R1 | RabbitMQ Quorum Queue |
| mq-02 | AZ2 | FD1 | R4 | RabbitMQ Quorum Queue |
| mq-03 | AZ3 | FD1 | R7 | RabbitMQ Quorum Queue |
| lb-01 | AZ1 | FD1 | R1 | HAProxy + Keepalived (MASTER) |
| lb-02 | AZ2 | FD1 | R4 | HAProxy + Keepalived (BACKUP) |
| lb-03 | AZ3 | FD1 | R7 | HAProxy + Keepalived (BACKUP) |

### Compute Plane (102 nós total)

A distribuição reflete a presença dos spines nos racks FD2, que cedem 2 slots de compute cada.

| Rack | AZ | FD | Compute Nodes |
|------|----|----|--------------:|
| R1 | AZ1 | FD1 | 12 |
| R2 | AZ1 | FD2 | 10 (spine-01 ocupa 2 slots) |
| R3 | AZ1 | FD3 | 12 |
| R4 | AZ2 | FD1 | 12 |
| R5 | AZ2 | FD2 | 10 (spine-02 ocupa 2 slots) |
| R6 | AZ2 | FD3 | 12 |
| R7 | AZ3 | FD1 | 12 |
| R8 | AZ3 | FD2 | 10 (spine-03 ocupa 2 slots) |
| R9 | AZ3 | FD3 | 12 |
| **Total** |    |    | **102** |

- Cada AZ: 34 compute nodes (12+10+12)
- Overcommit ratio: 3:1 CPU / 1.5:1 RAM (tier shared) e 1:1 (tier dedicated)

### GPU Compute Plane (9 nós total)

- 1 GPU node por rack × 9 racks = 9 GPU nodes
- Cada AZ: 3 GPU nodes (1 por FD)
- Overcommit: 1:1 (sem overcommit)
- Detalhes em `docs/09-gpu-compute.md`

### Storage Plane

| Nó | AZ | FD | Rack | Função |
|----|----|----|------|--------|
| swift-01..06 | AZ1 | FD1-3 | R1-R3 | Swift Object (2 por rack) |
| swift-07..12 | AZ2 | FD1-3 | R4-R6 | Swift Object (2 por rack) |
| swift-13..18 | AZ3 | FD1-3 | R7-R9 | Swift Object (2 por rack) |
| cinder-01..03 | AZ1-3 | FD1 | R1,R4,R7 | Cinder Volume (LVM/NVMe) |

### Network Plane

| Nó | AZ | FD | Rack | Função |
|----|----|----|------|--------|
| net-01..02 | AZ1 | FD2-3 | R2-R3 | OVN Gateway, Octavia |
| net-03..04 | AZ2 | FD2-3 | R5-R6 | OVN Gateway, Octavia |
| net-05..06 | AZ3 | FD2-3 | R8-R9 | OVN Gateway, Octavia |

### HSM Plane (Hardware Security Modules)

| Appliance | AZ | FD | Rack | Função |
|-----------|----|----|------|--------|
| hsm-az1-01 | AZ1 | FD1 | R1 | Partição primária (HA active-active) |
| hsm-az2-01 | AZ2 | FD1 | R4 | Partição replicada (HA active-active) |
| hsm-az3-01 | AZ3 | FD1 | R7 | Partição replicada (HA active-active) |

Detalhes em `docs/10-hsm-key-management.md`.

### Spine Plane (Core Fabric)

| Spine | AZ | FD | Rack | Função |
|-------|----|----|------|--------|
| spine-01 | AZ1 | FD2 | R2 | Core fabric — AZ1 |
| spine-02 | AZ2 | FD2 | R5 | Core fabric — AZ2 |
| spine-03 | AZ3 | FD2 | R8 | Core fabric — AZ3 |

Cada leaf tem 3 uplinks 100GbE (1 para cada spine). Os 3 spines formam full-mesh triangular (3 links inter-spine). Falha de um spine mantém 2/3 da capacidade underlay; ECMP redistribui fluxos automaticamente via BGP/BFD.

## Hardware — Requisitos Técnicos (Bill of Materials)

> As especificações abaixo representam requisitos técnicos mínimos. Qualquer equipamento que atenda ou supere esses requisitos e que suporte as APIs e padrões listados (IPMI 2.0, Redfish, PCIe Gen4, PKCS#11, etc.) é compatível com a arquitetura.

### Control Plane Nodes (12 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 1U, dual-socket |
| CPU | 2x processadores x86_64, 28 cores / 56 threads cada, base clock ≥ 2.6 GHz, suporte AVX-512 |
| RAM | 256 GB DDR4-3200 ECC RDIMM (expansível a 1 TB) |
| Boot | 2x SSD SATA 480 GB em RAID1 (hardware ou software) |
| Data | 2x NVMe SFF 1.92 TB |
| NIC | 2x portas 25GbE com suporte a RDMA (RoCEv2), SR-IOV |
| Gerenciamento OOB | Controladora BMC com suporte a IPMI 2.0 e Redfish |
| PSU | 2x 800W Platinum, hot-swap, feeds redundantes |

### Compute Nodes (102 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 2U, dual-socket |
| CPU | 2x processadores x86_64, 40 cores / 80 threads cada, base clock ≥ 2.3 GHz, suporte a VT-x, VT-d/IOMMU, AVX-512, EPT |
| RAM | 1 TB DDR4-3200 ECC RDIMM |
| Boot | 2x SSD SATA 480 GB em RAID1 |
| Local Storage | 2x NVMe SFF 3.84 TB (ephemeral) |
| NIC | 2x portas 25GbE com RDMA, SR-IOV, multiqueue |
| Gerenciamento OOB | BMC com IPMI 2.0 e Redfish |
| PSU | 2x 1400W Platinum, hot-swap, feeds redundantes |

### GPU Compute Nodes (9 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 4U, dual-socket, com suporte a aceleradores PCIe Gen5 x16 e SXM |
| CPU | 2x processadores x86_64, 40 cores / 80 threads cada, suporte a VT-d/IOMMU |
| RAM | 1 TB DDR4-3200 ECC RDIMM |
| GPU | 4x aceleradores compute-class: 80 GB HBM2e VRAM, interconexão NVLink ≥ 600 GB/s bidirecional, form factor SXM4, suporte a MIG, FP64 ≥ 9 TFLOPS, FP32 ≥ 19 TFLOPS, TF32 ≥ 150 TFLOPS, API CUDA compatível |
| Boot | 2x SSD SATA 480 GB em RAID1 |
| Local Storage | 2x NVMe SFF 3.84 TB |
| NIC | 2x portas 25GbE com RDMA, SR-IOV |
| Gerenciamento OOB | BMC com IPMI 2.0 e Redfish |
| PSU | 2x 2400W Platinum, hot-swap, feeds redundantes |
| Cooling | Direct liquid cooling para GPUs (TDP ≥ 400W por GPU) + air cooling para CPUs |

### Storage Nodes — Swift (18 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 2U com 12+ baias front-facing LFF |
| CPU | 2x processadores x86_64, 28 cores / 56 threads cada, base clock ≥ 2.0 GHz |
| RAM | 256 GB DDR4-3200 ECC RDIMM |
| Boot | 2x SSD SATA 480 GB em RAID1 |
| Object | 12x HDD SAS 12Gbps 16 TB (7.2k RPM) |
| Account/Container | 2x NVMe SFF 1.92 TB |
| NIC | 2x portas 25GbE com RDMA |
| Gerenciamento OOB | BMC com IPMI 2.0 e Redfish |
| PSU | 2x 1400W Platinum, hot-swap |

### Storage Nodes — Cinder (3 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 2U com 24+ baias NVMe SFF (U.2, E3.S/EDSFF ou equivalente PCIe Gen4+) |
| CPU | 2x processadores x86_64, 28 cores / 56 threads cada, base clock ≥ 2.0 GHz |
| RAM | 512 GB DDR4-3200 ECC RDIMM |
| Boot | 2x SSD SATA 480 GB em RAID1 |
| Block | 24x NVMe SFF 3.84 TB (U.2, E3.S/EDSFF ou equivalente) |
| NIC | 2x portas 25GbE com RDMA, suporte NVMe-oF |
| HBA | Controladora Tri-mode SAS/SATA/NVMe com ≥ 16 portas |
| Gerenciamento OOB | BMC com IPMI 2.0 e Redfish |
| PSU | 2x 1400W Platinum, hot-swap |

### Network Nodes (6 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 1U, dual-socket |
| CPU | 2x processadores x86_64, 16 cores / 32 threads cada, base clock ≥ 2.9 GHz |
| RAM | 128 GB DDR4-3200 ECC RDIMM |
| Boot | 2x SSD SATA 480 GB em RAID1 |
| NIC | 4x portas 25GbE (8 portas totais) com RDMA, SR-IOV, DPDK |
| Gerenciamento OOB | BMC com IPMI 2.0 e Redfish |
| PSU | 2x 800W Platinum, hot-swap |

### HSM Appliances (3 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Appliance de rede 1U, rack-mount |
| Certificação | FIPS 140-2 Level 3 (ou FIPS 140-3 Level 3) |
| Performance | ≥ 20.000 operações RSA-2048 sign/s |
| Algoritmos | RSA (1024-4096), ECC (P-256, P-384, P-521), AES (128/192/256), SHA-2 (256/384/512), HMAC, 3DES |
| Partições | ≥ 100 partições isoladas por appliance |
| Conectividade | 2x portas 1GbE em bonding para HA |
| API | PKCS#11 v2.40+, KMIP 1.4+ |
| HA | Suporte a replicação síncrona de chaves e HA group entre múltiplas unidades |
| Tamper | Detecção física com zeroização automática em violação |
| Backup | Suporte a backup criptografado para appliance offline ou cofre |

### Switches — Leaf/ToR (18 unidades — 2 por rack)

| Componente | Requisito Técnico |
|------------|-------------------|
| Ports | 32x 100GbE QSFP28, com breakout para 4x 25GbE por porta |
| Uplinks | 3x 100GbE para camada Spine (1 por spine, full-mesh triangular) |
| Downlinks | 29x 100GbE (breakout 25GbE para hosts = 116 portas 25GbE) |
| Protocolo | BGP, EVPN, MLAG, BFD, VXLAN hardware offload |
| Buffer | ≥ 16 MB shared buffer |
| Latência | ≤ 500 ns port-to-port |
| OS | Network OS aberto/programável com APIs declarativas |

### Switches — Spine (3 unidades — 1 por AZ, alojados em R2, R5, R8)

| Componente | Requisito Técnico |
|------------|-------------------|
| Ports | 32x 400GbE QSFP-DD, com breakout para 4x 100GbE por porta |
| Conectividade | Full-mesh triangular entre os 3 Spines (1 link por par) |
| Uplinks para leaves | 18 portas 100GbE (1 por leaf, todos os 18 leaves do fabric) |
| Protocolo | BGP (eBGP underlay), EVPN (overlay), BFD, ECMP |
| Latência | ≤ 500 ns port-to-port |
| OS | Network OS aberto/programável |

### Switches — Management OOB (9 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Ports | 48x 1GbE base-T + 4x 10GbE uplink |
| Função | Gerenciamento OOB, IPMI, PXE Boot, provisionamento |
| Isolamento | VLAN isolada da rede de dados |

## Energia e Cooling

### Distribuição de Energia

```
Utility Feed A ──► ATS-A ──► PDU-A (Rack Left)
Utility Feed B ──► ATS-B ──► PDU-B (Rack Right)
```

- Cada rack: 2x PDU (feed A + feed B)
- Cada servidor: 2x PSU (uma por PDU)
- UPS: 2x por fileira (N+1)
- Gerador: 1x por AZ (diesel, 72h autonomia)

### Capacidade por Rack

Todos os 9 racks possuem 1 GPU node (4U, liquid cooling direto integrado no servidor).
O rack FD1 tem maior densidade elétrica por acumular também Cinder NVMe e HSM.

| Métrica | Rack FD2 / FD3 (compute + GPU + Swift) | Rack FD1 (control plane + Cinder + HSM + GPU) |
|---------|----------------------------------------|-----------------------------------------------|
| Potência máxima | 22 kW | 30 kW |
| Potência típica | 15 kW | 22 kW |
| Cooling | In-row cooling N+1 + liquid cooling direto (GPU) | In-row cooling N+1 + liquid cooling direto (GPU) + rear-door heat exchanger |
| Temperatura | 18-27°C (ASHRAE A1) | 18-27°C (ASHRAE A1) |
| Umidade | 40-60% RH | 40-60% RH |

## Naming Convention

```
Formato: {role}-{az}{fd}-{seq}.cloud.internal

Exemplos:
  ctrl-az1fd1-01.cloud.internal
  compute-az2fd3-07.cloud.internal
  gpu-az1fd1-01.cloud.internal
  swift-az3fd2-02.cloud.internal
  hsm-az1-01.cloud.internal
  leaf-az1fd1-a.cloud.internal
  spine-01.cloud.internal
```

## Resumo Quantitativo

| Categoria | Quantidade |
|-----------|-----------|
| Racks | 9 |
| Control Nodes | 12 |
| Compute Nodes | 102 |
| GPU Compute Nodes | 9 |
| Swift Storage Nodes | 18 |
| Cinder Storage Nodes | 3 |
| Network Nodes | 6 |
| HSM Appliances | 3 |
| Leaf Switches | 18 |
| Spine Switches | 3 (1 por AZ, em R2/R5/R8) |
| OOB Switches | 9 |
| **Total Servidores** | **150** |
| **Total Appliances** | **3** (HSM) |
| **Total vCPUs (compute)** | 16.320 (102 × 160 threads) |
| **Total RAM (compute)** | 102 TB |
| **Total GPUs** | 36 (9 × 4) |
| **Total VRAM** | 2.880 GB (36 × 80 GB) |
| **Total Object Storage** | 3.456 PB raw (18 × 12 × 16TB) |
| **Total Block Storage** | 276 TB NVMe (3 × 24 × 3.84TB) |

## Decisões Arquiteturais

1. **3 AZs com 3 FDs cada**: Garante que qualquer falha de rack afeta no máximo 1/9 da capacidade.
2. **Control Plane distribuído**: Um nó de cada serviço por AZ elimina SPOF.
3. **Spine-Leaf com 3 spines distribuídos**: Um spine por AZ (em R2/R5/R8) aloja o core fabric junto dos demais equipamentos; falha de rack FD2 de uma AZ remove 1 spine + 10 computes + 2 Swift + 1 GPU, mas o ECMP mantém 2/3 da bandwidth underlay e o control plane sobrevive via quorum 2/3.
4. **Full-mesh triangular entre spines**: 3 links inter-spine (1 por par) mantêm caminhos de backup para tráfego entre leaves de AZs distintas sem depender de um único spine.
5. **Trade-off explícito de capacidade**: Manter apenas 9 racks custou 6 compute nodes (108 → 102) e 1 spine a menos (4 → 3). A decisão prioriza footprint físico e simplicidade operacional sobre capacidade bruta.
6. **25GbE para hosts**: Custo-benefício ideal para workloads enterprise; RDMA e SR-IOV obrigatórios.
7. **NVMe para Cinder**: Latência sub-milissegundo para block storage. O form factor (U.2, E3.S/EDSFF ou equivalente) é definido pelo servidor escolhido; o requisito é NVMe PCIe Gen4+ com ≥ 3.84 TB por baia.
8. **HDD para Swift**: Custo/TB otimizado para object storage com replicação 3x.
9. **Dual-homed networking**: Cada host com 2 NICs em switches distintos (MLAG).
10. **GPU compute plane dedicado**: Aceleradores em nós separados, 1 por FD, distribuindo risco entre AZs.
11. **HSM em FD1 de cada AZ**: Cluster de 3 appliances em HA active-active para chaves criptográficas FIPS 140-2 Level 3.
12. **Requisitos técnicos agnósticos de marca**: Especificações baseadas em padrões abertos (IPMI, Redfish, PKCS#11, PCIe) permitem múltiplos fornecedores.

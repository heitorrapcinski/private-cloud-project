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

Cada rack (42U) segue um layout lógico padronizado. Racks de FD1 (R1, R4, R7) recebem também appliances HSM, enquanto todos os racks recebem um nó GPU.

### Rack Padrão (FD2, FD3 — R2, R3, R5, R6, R8, R9)

| Posição U | Equipamento | Função |
|-----------|-------------|--------|
| U1-U2 | PDU A + PDU B | Energia redundante (feeds distintos) |
| U3 | Patch Panel Fibra | Uplinks Spine |
| U4 | ToR Switch A (Leaf) | Rede primária |
| U5 | ToR Switch B (Leaf) | Rede redundante |
| U6 | Management Switch | OOB/IPMI |
| U7-U30 | Compute Nodes (12x 2U) | KVM Hypervisors |
| U31-U32 | GPU Compute Node (1x 2U) | Aceleração GPU |
| U33-U36 | Swift Storage Nodes (2x 2U) | Object Storage |
| U37-U38 | Network Nodes (1x 1U) ou Reserva | OVN Gateway |
| U39-U42 | Cable Management / Reserva | Organização e expansão |

### Rack FD1 (R1, R4, R7 — um por AZ)

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
| U37-U38 | GPU Compute Node (1x 2U) | Aceleração GPU |
| U39 | HSM Appliance (1x 1U) | Gestão de chaves criptográficas |
| U40 | Network Node (1x 1U) | OVN Gateway |
| U41-U42 | Cable Management | Organização |

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

### Compute Plane (108 nós total)

- 12 compute nodes por rack × 9 racks = 108 hypervisors
- Cada AZ: 36 compute nodes (12 por FD)
- Overcommit ratio: 3:1 CPU / 1.5:1 RAM (tier shared) e 1:1 (tier dedicated)

### GPU Compute Plane (9 nós total)

- 1 GPU node por rack × 9 racks = 9 GPU nodes
- Cada AZ: 3 GPU nodes (1 por FD)
- Overcommit: 1:1 (sem overcommit)
- Detalhes em `docs/10-gpu-compute.md`

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
| hsm-az1-01 | AZ1 | FD1 | R1 | Partição primária (HA activeE) |
| hsm-az2-01 | AZ2 | FD1 | R4 | Partição replicada (HA activeE) |
| hsm-az3-01 | AZ3 | FD1 | R7 | Partição replicada (HA activeE) |

Detalhes em `docs/11-hsm-key-management.md`.

## Hardware — Requisitos Técnicos (Bill of Materials)

> As especificações abaixo representam requisitos técnicos mínimos. Qualquer equipamento que atenda ou supere esses requisitos e que suporte as APIs e padrões listados (IPMI 2.0, Redfish, PCIe Gen4, PKCS#11, etc.) é compatível com a arquitetura.

### Control Plane Nodes (12 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 1U, dual-socket |
| CPU | 2x processadores x86_64, 28 cores / 56 threads cada, base clock ≥ 2.6 GHz, suporte AVX-512 |
| RAM | 256 GB DDR4-3200 ECC RDIMM (expansível a 1 TB) |
| Boot | 2x SSD SATA 480 GB em RAID1 (hardware ou software) |
| Data | 2x NVMe U.2 1.92 TB |
| NIC | 2x portas 25GbE com suporte a RDMA (RoCEv2), SR-IOV |
| Gerenciamento OOB | Controladora BMC com suporte a IPMI 2.0 e Redfish |
| PSU | 2x 800W Platinum, hot-swap, feeds redundantes |

### Compute Nodes (108 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 2U, dual-socket |
| CPU | 2x processadores x86_64, 40 cores / 80 threads cada, base clock ≥ 2.3 GHz, suporte a VT-x, VT-d/IOMMU, AVX-512, EPT |
| RAM | 1 TB DDR4-3200 ECC RDIMM |
| Boot | 2x SSD SATA 480 GB em RAID1 |
| Local Storage | 2x NVMe U.2 3.84 TB (ephemeral) |
| NIC | 2x portas 25GbE com RDMA, SR-IOV, multiqueue |
| Gerenciamento OOB | BMC com IPMI 2.0 e Redfish |
| PSU | 2x 1400W Platinum, hot-swap, feeds redundantes |

### GPU Compute Nodes (9 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 2U, dual-socket, com suporte a aceleradores PCIe Gen4 x16 e SXM |
| CPU | 2x processadores x86_64, 40 cores / 80 threads cada, suporte a VT-d/IOMMU |
| RAM | 1 TB DDR4-3200 ECC RDIMM |
| GPU | 4x aceleradores compute-class: 80 GB HBM2e VRAM, interconexão NVLink ≥ 600 GB/s bidirecional, form factor SXM4, suporte a MIG, FP64 ≥ 9 TFLOPS, FP32 ≥ 19 TFLOPS, TF32 ≥ 150 TFLOPS, API CUDA compatível |
| Boot | 2x SSD SATA 480 GB em RAID1 |
| Local Storage | 2x NVMe U.2 3.84 TB |
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
| Account/Container | 2x NVMe U.2 1.92 TB |
| NIC | 2x portas 25GbE com RDMA |
| Gerenciamento OOB | BMC com IPMI 2.0 e Redfish |
| PSU | 2x 1400W Platinum, hot-swap |

### Storage Nodes — Cinder (3 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 2U com 24+ baias NVMe U.2 |
| CPU | 2x processadores x86_64, 28 cores / 56 threads cada, base clock ≥ 2.0 GHz |
| RAM | 512 GB DDR4-3200 ECC RDIMM |
| Boot | 2x SSD SATA 480 GB em RAID1 |
| Block | 24x NVMe U.2 3.84 TB |
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
| Uplinks | 4x 100GbE para camada Spine |
| Downlinks | 28x 100GbE (breakout 25GbE para hosts = 112 portas 25GbE) |
| Protocolo | BGP, EVPN, MLAG, BFD, VXLAN hardware offload |
| Buffer | ≥ 16 MB shared buffer |
| Latência | ≤ 500 ns port-to-port |
| OS | Network OS aberto/programável com APIs declarativas |

### Switches — Spine (4 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Ports | 32x 400GbE QSFP-DD, com breakout para 4x 100GbE por porta |
| Conectividade | Full-mesh entre Spines |
| Protocolo | BGP (eBGP underlay), EVPN (overlay), BFD |
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

| Métrica | Rack Padrão | Rack FD1 (com GPU + HSM + Cinder) |
|---------|-------------|-----------------------------------|
| Potência máxima | 20 kW | 28 kW (liquid cooling para GPU) |
| Potência típica | 14 kW | 20 kW |
| Cooling | In-row cooling (N+1) | In-row cooling + rear-door heat exchanger |
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
| Compute Nodes | 108 |
| GPU Compute Nodes | 9 |
| Swift Storage Nodes | 18 |
| Cinder Storage Nodes | 3 |
| Network Nodes | 6 |
| HSM Appliances | 3 |
| Leaf Switches | 18 |
| Spine Switches | 4 |
| OOB Switches | 9 |
| **Total Servidores** | **156** |
| **Total Appliances** | **3** (HSM) |
| **Total vCPUs (compute)** | 17.280 (108 × 160 threads) |
| **Total RAM (compute)** | 108 TB |
| **Total GPUs** | 36 (9 × 4) |
| **Total VRAM** | 2.880 GB (36 × 80 GB) |
| **Total Object Storage** | 3.456 PB raw (18 × 12 × 16TB) |
| **Total Block Storage** | 276 TB NVMe (3 × 24 × 3.84TB) |

## Decisões Arquiteturais

1. **3 AZs com 3 FDs cada**: Garante que qualquer falha de rack afeta no máximo 1/9 da capacidade.
2. **Control Plane distribuído**: Um nó de cada serviço por AZ elimina SPOF.
3. **Spine-Leaf**: Latência previsível, escalabilidade horizontal, sem STP.
4. **25GbE para hosts**: Custo-benefício ideal para workloads enterprise; RDMA e SR-IOV obrigatórios.
5. **NVMe para Cinder**: Latência sub-milissegundo para block storage.
6. **HDD para Swift**: Custo/TB otimizado para object storage com replicação 3x.
7. **Dual-homed networking**: Cada host com 2 NICs em switches distintos (MLAG).
8. **GPU compute plane dedicado**: Aceleradores em nós separados, 1 por FD, distribuindo risco entre AZs.
9. **HSM em FD1 de cada AZ**: Cluster de 3 appliances em HA activeE para chaves criptográficas FIPS 140-2 Level 3.
10. **Requisitos técnicos agnósticos de marca**: Especificações baseadas em padrões abertos (IPMI, Redfish, PKCS#11, PCIe) permitem múltiplos fornecedores.

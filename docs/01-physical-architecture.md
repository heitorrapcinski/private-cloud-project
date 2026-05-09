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

Cada rack (42U) segue o layout padrão:

| Posição U | Equipamento | Função |
|-----------|-------------|--------|
| U1-U2 | PDU A + PDU B | Energia redundante (feeds distintos) |
| U3 | Patch Panel Fibra | Uplinks Spine |
| U4 | ToR Switch A (Leaf) | Rede primária |
| U5 | ToR Switch B (Leaf) | Rede redundante |
| U6 | Management Switch | OOB/IPMI |
| U7-U10 | Control Plane Nodes (3x 1U) | API, DB, MQ |
| U11-U34 | Compute Nodes (12x 2U) | KVM Hypervisors |
| U35-U38 | Storage Nodes (2x 2U) | Cinder/Swift |
| U39-U40 | Network Nodes (2x 1U) | Neutron Gateway |
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
- Overcommit ratio: 4:1 CPU, 1.5:1 RAM

### Storage Plane

| Nó | AZ | FD | Rack | Função |
|----|----|----|------|--------|
| swift-01..06 | AZ1 | FD1-3 | R1-R3 | Swift Object (2 por rack) |
| swift-07..12 | AZ2 | FD1-3 | R4-R6 | Swift Object (2 por rack) |
| swift-13..18 | AZ3 | FD1-3 | R7-R9 | Swift Object (2 por rack) |
| cinder-01..03 | AZ1-3 | FD1 | R1,R4,R7 | Cinder Volume (LVM/Ceph) |

### Network Plane

| Nó | AZ | FD | Rack | Função |
|----|----|----|------|--------|
| net-01..02 | AZ1 | FD2-3 | R2-R3 | OVN Gateway, Octavia |
| net-03..04 | AZ2 | FD2-3 | R5-R6 | OVN Gateway, Octavia |
| net-05..06 | AZ3 | FD2-3 | R8-R9 | OVN Gateway, Octavia |

## Hardware BOM (Bill of Materials)

### Control Plane Nodes (12 unidades)

| Componente | Especificação |
|------------|---------------|
| Servidor | Dell PowerEdge R650 (1U) |
| CPU | 2x Intel Xeon Gold 6348 (28C/56T) |
| RAM | 256 GB DDR4-3200 ECC RDIMM |
| Boot | 2x 480GB SSD SATA (RAID1) |
| Data | 2x 1.92TB NVMe U.2 |
| NIC | 2x Mellanox ConnectX-6 25GbE (4 ports) |
| IPMI | iDRAC 9 Enterprise |
| PSU | 2x 800W Platinum (redundante) |

### Compute Nodes (108 unidades)

| Componente | Especificação |
|------------|---------------|
| Servidor | Dell PowerEdge R750 (2U) |
| CPU | 2x Intel Xeon Platinum 8380 (40C/80T) |
| RAM | 1 TB DDR4-3200 ECC RDIMM |
| Boot | 2x 480GB SSD SATA (RAID1) |
| Local Storage | 2x 3.84TB NVMe (ephemeral) |
| NIC | 2x Mellanox ConnectX-6 25GbE (4 ports) |
| IPMI | iDRAC 9 Enterprise |
| PSU | 2x 1400W Platinum (redundante) |

### Storage Nodes - Swift (18 unidades)

| Componente | Especificação |
|------------|---------------|
| Servidor | Dell PowerEdge R750xd (2U) |
| CPU | 2x Intel Xeon Gold 6330 (28C/56T) |
| RAM | 256 GB DDR4-3200 ECC RDIMM |
| Boot | 2x 480GB SSD SATA (RAID1) |
| Object | 12x 16TB HDD SAS 12Gbps |
| Account/Container | 2x 1.92TB NVMe |
| NIC | 2x Mellanox ConnectX-6 25GbE (4 ports) |
| IPMI | iDRAC 9 Enterprise |
| PSU | 2x 1400W Platinum (redundante) |

### Storage Nodes - Cinder (3 unidades)

| Componente | Especificação |
|------------|---------------|
| Servidor | Dell PowerEdge R750xd (2U) |
| CPU | 2x Intel Xeon Gold 6330 (28C/56T) |
| RAM | 512 GB DDR4-3200 ECC RDIMM |
| Boot | 2x 480GB SSD SATA (RAID1) |
| Block | 24x 3.84TB NVMe U.2 |
| NIC | 2x Mellanox ConnectX-6 25GbE (4 ports) |
| HBA | Broadcom MegaRAID 9560-16i |
| IPMI | iDRAC 9 Enterprise |
| PSU | 2x 1400W Platinum (redundante) |

### Network Nodes (6 unidades)

| Componente | Especificação |
|------------|---------------|
| Servidor | Dell PowerEdge R650 (1U) |
| CPU | 2x Intel Xeon Gold 6326 (16C/32T) |
| RAM | 128 GB DDR4-3200 ECC RDIMM |
| Boot | 2x 480GB SSD SATA (RAID1) |
| NIC | 4x Mellanox ConnectX-6 25GbE (8 ports total) |
| IPMI | iDRAC 9 Enterprise |
| PSU | 2x 800W Platinum (redundante) |

### Switches - Leaf/ToR (18 unidades - 2 por rack)

| Componente | Especificação |
|------------|---------------|
| Modelo | Mellanox SN3700C |
| Ports | 32x 100GbE QSFP28 |
| Breakout | 4x 25GbE por port |
| Uplinks | 4x 100GbE para Spine |
| Downlinks | 28x 100GbE (breakout 25GbE para hosts) |
| Protocolo | BGP/EVPN, MLAG |

### Switches - Spine (4 unidades)

| Componente | Especificação |
|------------|---------------|
| Modelo | Mellanox SN4700 |
| Ports | 32x 400GbE QSFP-DD |
| Breakout | 4x 100GbE por port |
| Conectividade | Full-mesh entre Spines |
| Protocolo | BGP (eBGP underlay), EVPN (overlay) |

### Switches - Management OOB (9 unidades)

| Componente | Especificação |
|------------|---------------|
| Modelo | Dell S3048-ON |
| Ports | 48x 1GbE + 4x 10GbE |
| Função | IPMI, PXE Boot, Management |

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

| Métrica | Valor |
|---------|-------|
| Potência máxima | 20 kW |
| Potência típica | 14 kW |
| Cooling | In-row cooling (N+1) |
| Temperatura | 18-27°C (ASHRAE A1) |
| Umidade | 40-60% RH |

## Naming Convention

```
Formato: {role}-{az}{fd}-{seq}.cloud.internal

Exemplos:
  ctrl-az1fd1-01.cloud.internal
  compute-az2fd3-07.cloud.internal
  swift-az3fd2-02.cloud.internal
  leaf-az1fd1-a.cloud.internal
  spine-01.cloud.internal
```

## Resumo Quantitativo

| Categoria | Quantidade |
|-----------|-----------|
| Racks | 9 |
| Control Nodes | 12 |
| Compute Nodes | 108 |
| Swift Storage Nodes | 18 |
| Cinder Storage Nodes | 3 |
| Network Nodes | 6 |
| Leaf Switches | 18 |
| Spine Switches | 4 |
| OOB Switches | 9 |
| **Total Servidores** | **147** |
| **Total vCPUs** | 17,280 (108 × 160 cores) |
| **Total RAM** | 108 TB (compute) |
| **Total Object Storage** | 3.456 PB raw (18 × 12 × 16TB) |
| **Total Block Storage** | 276 TB NVMe (3 × 24 × 3.84TB) |

## Decisões Arquiteturais

1. **3 AZs com 3 FDs cada**: Garante que qualquer falha de rack afeta no máximo 1/9 da capacidade
2. **Control Plane distribuído**: Um nó de cada serviço por AZ elimina SPOF
3. **Spine-Leaf**: Latência previsível, escalabilidade horizontal, sem STP
4. **25GbE para hosts**: Custo-benefício ideal para workloads enterprise
5. **NVMe para Cinder**: Latência sub-milissegundo para block storage
6. **HDD para Swift**: Custo/TB otimizado para object storage com replicação 3x
7. **Dual-homed networking**: Cada host com 2 NICs em switches distintos (MLAG)

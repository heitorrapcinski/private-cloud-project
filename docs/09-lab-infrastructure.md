# 09 - Infraestrutura de Laboratório de Desenvolvimento

## Visão Geral

Ambiente de laboratório para desenvolvimento, testes de integração e validação de mudanças antes da promoção ao ambiente de produção. O lab replica a arquitetura de produção em escala reduzida, mantendo a mesma topologia lógica.

```
┌─────────────────────────────────────────────────────────────────┐
│                    LAB: RegionLab                                 │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  1 Rack (42U)                            │    │
│  │                                                          │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐             │    │
│  │  │ Control  │  │ Compute  │  │ Storage  │             │    │
│  │  │  3 nodes │  │  6 nodes │  │  3 nodes │             │    │
│  │  └──────────┘  └──────────┘  └──────────┘             │    │
│  │                                                          │    │
│  │  ┌──────────┐  ┌──────────┐                            │    │
│  │  │ Network  │  │  Infra   │                            │    │
│  │  │  2 nodes │  │  2 nodes │                            │    │
│  │  └──────────┘  └──────────┘                            │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Objetivos do Laboratório

| Objetivo | Descrição |
|----------|-----------|
| Validação de upgrades | Testar upgrades de OpenStack antes de produção |
| Desenvolvimento de automação | Desenvolver e testar playbooks Ansible e Terraform |
| Testes de integração | Validar integrações entre serviços OpenStack |
| Treinamento | Capacitação da equipe em operações de nuvem |
| PoC de features | Avaliar novos serviços e configurações |
| Testes de DR | Simular cenários de falha e recuperação |

## Topologia Física

### Layout do Rack (1x 42U)

| Posição U | Equipamento | Função |
|-----------|-------------|--------|
| U1-U2 | PDU A + PDU B | Energia redundante |
| U3 | Patch Panel | Cabeamento estruturado |
| U4 | ToR Switch A | Leaf primário |
| U5 | ToR Switch B | Leaf secundário |
| U6 | Management Switch | OOB/IPMI |
| U7-U9 | Control Nodes (3x 1U) | API, DB, MQ |
| U10-U21 | Compute Nodes (6x 2U) | KVM Hypervisors |
| U22-U27 | Storage Nodes (3x 2U) | Cinder + Swift |
| U28-U29 | Network Nodes (2x 1U) | OVN Gateway |
| U30-U31 | Infra Nodes (2x 1U) | CI/CD, Monitoring |
| U32-U42 | Reserva | Expansão futura |

## Hardware BOM (Lab)

### Control Nodes (3 unidades)

| Componente | Especificação |
|------------|---------------|
| Servidor | Dell PowerEdge R650xs (1U) |
| CPU | 1x Intel Xeon Silver 4314 (16C/32T) |
| RAM | 128 GB DDR4-3200 ECC |
| Boot | 2x 240GB SSD SATA (RAID1) |
| Data | 1x 960GB NVMe |
| NIC | 2x 25GbE (Mellanox ConnectX-5) |
| IPMI | iDRAC 9 Express |
| PSU | 2x 600W (redundante) |

### Compute Nodes (6 unidades)

| Componente | Especificação |
|------------|---------------|
| Servidor | Dell PowerEdge R750xs (2U) |
| CPU | 2x Intel Xeon Silver 4316 (20C/40T) |
| RAM | 512 GB DDR4-3200 ECC |
| Boot | 2x 240GB SSD SATA (RAID1) |
| Local Storage | 2x 1.92TB NVMe (ephemeral) |
| NIC | 2x 25GbE (Mellanox ConnectX-5) |
| IPMI | iDRAC 9 Express |
| PSU | 2x 800W (redundante) |

### Storage Nodes (3 unidades)

| Componente | Especificação |
|------------|---------------|
| Servidor | Dell PowerEdge R750xd (2U) |
| CPU | 1x Intel Xeon Silver 4314 (16C/32T) |
| RAM | 128 GB DDR4-3200 ECC |
| Boot | 2x 240GB SSD SATA (RAID1) |
| Object | 6x 4TB HDD SAS |
| Block | 4x 1.92TB NVMe |
| NIC | 2x 25GbE (Mellanox ConnectX-5) |
| IPMI | iDRAC 9 Express |
| PSU | 2x 800W (redundante) |

### Network Nodes (2 unidades)

| Componente | Especificação |
|------------|---------------|
| Servidor | Dell PowerEdge R650xs (1U) |
| CPU | 1x Intel Xeon Silver 4310 (12C/24T) |
| RAM | 64 GB DDR4-3200 ECC |
| Boot | 2x 240GB SSD SATA (RAID1) |
| NIC | 2x 25GbE (Mellanox ConnectX-5) |
| IPMI | iDRAC 9 Express |
| PSU | 2x 600W (redundante) |

### Infra Nodes (2 unidades)

| Componente | Especificação |
|------------|---------------|
| Servidor | Dell PowerEdge R650xs (1U) |
| CPU | 1x Intel Xeon Silver 4310 (12C/24T) |
| RAM | 64 GB DDR4-3200 ECC |
| Boot | 2x 240GB SSD SATA (RAID1) |
| Data | 2x 960GB NVMe |
| NIC | 2x 25GbE (Mellanox ConnectX-5) |
| IPMI | iDRAC 9 Express |
| PSU | 2x 600W (redundante) |

### Switches

| Equipamento | Modelo | Ports | Função |
|-------------|--------|-------|--------|
| Leaf A | Mellanox SN2700 | 32x 100GbE | Rede primária |
| Leaf B | Mellanox SN2700 | 32x 100GbE | Rede redundante |
| OOB Switch | Dell S3048-ON | 48x 1GbE | Management/IPMI |

## Rede

### VLANs

| VLAN | Subnet | Função |
|------|--------|--------|
| 10 | 10.10.10.0/24 | Management |
| 20 | 10.10.20.0/24 | Internal API |
| 30 | 10.10.30.0/24 | Tenant (Geneve overlay) |
| 40 | 10.10.40.0/24 | Storage |
| 50 | 10.10.50.0/24 | External/Provider |
| 60 | 10.10.60.0/24 | IPMI/OOB |

### Diagrama de Rede

```
                    ┌──────────────┐
                    │   Upstream   │
                    │   Router     │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │                         │
        ┌─────┴─────┐           ┌─────┴─────┐
        │  Leaf A   │           │  Leaf B   │
        │ (SN2700)  │           │ (SN2700)  │
        └─────┬─────┘           └─────┬─────┘
              │                         │
              │    ┌─── MLAG ───┐      │
              │    │            │      │
        ┌─────┴────┴────────────┴──────┴─────┐
        │         All Server Nodes            │
        │    (dual-homed 25GbE per node)      │
        └─────────────────────────────────────┘
```

## Mapeamento Lab → Produção

| Aspecto | Produção | Lab | Ratio |
|---------|----------|-----|-------|
| Regiões | 1 | 1 | 1:1 |
| AZs | 3 | 1 (simulada) | 3:1 |
| Control Nodes | 12 | 3 | 4:1 |
| Compute Nodes | 108 | 6 | 18:1 |
| Storage Nodes | 21 | 3 | 7:1 |
| Network Nodes | 6 | 2 | 3:1 |
| Leaf Switches | 18 | 2 | 9:1 |
| Spine Switches | 4 | 0 (flat) | - |
| Total Servidores | 147 | 16 | ~9:1 |

## Serviços Deployados

### OpenStack (mesma versão de produção)

| Serviço | Nodes | Notas |
|---------|-------|-------|
| Keystone | ctrl-01..03 | HA com HAProxy |
| Nova | ctrl-01..03 + compute-01..06 | Single cell |
| Neutron (OVN) | ctrl-01..03 + net-01..02 | OVN Central + Gateway |
| Glance | ctrl-01..03 | Backend Swift |
| Cinder | ctrl-01..03 + storage-01..03 | NVMe LVM |
| Swift | storage-01..03 | 3 replicas (mínimo) |
| Horizon | ctrl-01..03 | Dashboard |
| Heat | ctrl-01..03 | Orchestration |
| Octavia | net-01..02 | LBaaS |
| Barbican | ctrl-01..03 | Secrets |
| Ironic | ctrl-01 | Bare metal (1 conductor) |

### Infraestrutura Auxiliar (Infra Nodes)

| Serviço | Node | Função |
|---------|------|--------|
| GitLab Runner | infra-01 | CI/CD pipelines |
| Prometheus + Grafana | infra-01 | Monitoramento |
| Loki + Fluentd | infra-02 | Logging centralizado |
| Harbor | infra-02 | Container registry |
| Vault | infra-01 | Secrets management |

## Configuração de Compute (Lab)

```ini
# /etc/nova/nova.conf (compute nodes - lab)
[compute]
cpu_allocation_ratio = 4.0
ram_allocation_ratio = 2.0
disk_allocation_ratio = 1.5

[libvirt]
virt_type = kvm
cpu_mode = host-passthrough
live_migration_uri = qemu+ssh://nova@%s/system
```

### Host Aggregates (Lab)

| Aggregate | Hosts | Metadata |
|-----------|-------|----------|
| lab-shared | compute-01..04 | overcommit_ratio=3:1, service_tier=shared |
| lab-dedicated | compute-05..06 | overcommit_ratio=1:1, service_tier=dedicated |

## Pipeline de Promoção

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│   Dev    │────►│   Lab    │────►│ Staging  │────►│   Prod   │
│ (local)  │     │ (deploy) │     │ (canary) │     │ (full)   │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
     │                │                │                │
     │                │                │                │
  Ansible          Tempest          Smoke            Rolling
  lint +           + Rally           tests           upgrade
  molecule         tests
```

### Critérios de Promoção Lab → Produção

1. Todos os testes Tempest passam (smoke + full)
2. Rally benchmarks dentro de ±10% da baseline
3. Upgrade path validado (N-1 → N)
4. Rollback testado e documentado
5. Runbooks atualizados
6. Aprovação do Change Advisory Board (CAB)

## Naming Convention (Lab)

```
Formato: lab-{role}-{seq}.lab.cloud.internal

Exemplos:
  lab-ctrl-01.lab.cloud.internal
  lab-compute-03.lab.cloud.internal
  lab-storage-02.lab.cloud.internal
  lab-net-01.lab.cloud.internal
  lab-infra-01.lab.cloud.internal
```

## Resumo Quantitativo (Lab)

| Categoria | Quantidade |
|-----------|-----------|
| Racks | 1 |
| Control Nodes | 3 |
| Compute Nodes | 6 |
| Storage Nodes | 3 |
| Network Nodes | 2 |
| Infra Nodes | 2 |
| Leaf Switches | 2 |
| OOB Switches | 1 |
| **Total Servidores** | **16** |
| **Total vCPUs** | 960 (6 × 160 vCPUs @ 4:1) |
| **Total RAM** | 3 TB (compute) |
| **Total Object Storage** | 72 TB raw (3 × 6 × 4TB) |
| **Total Block Storage** | 23 TB NVMe (3 × 4 × 1.92TB) |

## Decisões Arquiteturais

1. **Single rack**: Custo reduzido, suficiente para validação funcional
2. **Mesma stack de produção**: Garante paridade de testes
3. **6 compute nodes**: Permite testar live migration, HA e host aggregates
4. **Infra nodes separados**: CI/CD e monitoring não competem com OpenStack
5. **Hardware Silver-tier**: Custo-benefício para lab sem comprometer funcionalidade
6. **Single cell**: Simplifica operação do lab sem perder cobertura de testes
7. **Host aggregates para overcommit**: Replica modelo de ofertas de produção (shared/dedicated)

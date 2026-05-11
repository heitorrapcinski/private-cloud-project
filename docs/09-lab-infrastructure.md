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

## Hardware BOM (Lab) — Requisitos Técnicos

> Especificações representam requisitos técnicos mínimos; qualquer hardware que atenda ou supere esses requisitos e suporte as APIs listadas (IPMI 2.0, Redfish) é compatível.

### Control Nodes (3 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 1U, single ou dual-socket |
| CPU | 1x processador x86_64, 16 cores / 32 threads, base clock ≥ 2.4 GHz |
| RAM | 128 GB DDR4-3200 ECC |
| Boot | 2x SSD SATA 240 GB em RAID1 |
| Data | 1x NVMe 960 GB |
| NIC | 2x portas 25GbE com RDMA |
| Gerenciamento OOB | BMC com IPMI 2.0 e Redfish |
| PSU | 2x 600W, hot-swap, redundantes |

### Compute Nodes (6 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 2U, dual-socket |
| CPU | 2x processadores x86_64, 20 cores / 40 threads cada, suporte a VT-x, VT-d/IOMMU, AVX-512 |
| RAM | 512 GB DDR4-3200 ECC |
| Boot | 2x SSD SATA 240 GB em RAID1 |
| Local Storage | 2x NVMe 1.92 TB (ephemeral) |
| NIC | 2x portas 25GbE com RDMA, SR-IOV |
| Gerenciamento OOB | BMC com IPMI 2.0 e Redfish |
| PSU | 2x 800W, hot-swap, redundantes |

### Storage Nodes (3 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 2U com baias mistas (HDD + NVMe) |
| CPU | 1x processador x86_64, 16 cores / 32 threads, base clock ≥ 2.4 GHz |
| RAM | 128 GB DDR4-3200 ECC |
| Boot | 2x SSD SATA 240 GB em RAID1 |
| Object | 6x HDD SAS 12Gbps 4 TB |
| Block | 4x NVMe 1.92 TB |
| NIC | 2x portas 25GbE com RDMA |
| Gerenciamento OOB | BMC com IPMI 2.0 e Redfish |
| PSU | 2x 800W, hot-swap, redundantes |

### Network Nodes (2 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 1U |
| CPU | 1x processador x86_64, 12 cores / 24 threads, base clock ≥ 2.1 GHz |
| RAM | 64 GB DDR4-3200 ECC |
| Boot | 2x SSD SATA 240 GB em RAID1 |
| NIC | 2x portas 25GbE com RDMA, SR-IOV, DPDK |
| Gerenciamento OOB | BMC com IPMI 2.0 e Redfish |
| PSU | 2x 600W, hot-swap, redundantes |

### Infra Nodes (2 unidades)

| Componente | Requisito Técnico |
|------------|-------------------|
| Form factor | Servidor rack 1U |
| CPU | 1x processador x86_64, 12 cores / 24 threads, base clock ≥ 2.1 GHz |
| RAM | 64 GB DDR4-3200 ECC |
| Boot | 2x SSD SATA 240 GB em RAID1 |
| Data | 2x NVMe 960 GB |
| NIC | 2x portas 25GbE com RDMA |
| Gerenciamento OOB | BMC com IPMI 2.0 e Redfish |
| PSU | 2x 600W, hot-swap, redundantes |

### Switches

| Equipamento | Requisito Técnico | Função |
|-------------|-------------------|--------|
| Leaf A | Switch 32x 100GbE QSFP28, breakout 4x 25GbE, BGP/EVPN/MLAG | Rede primária |
| Leaf B | Switch 32x 100GbE QSFP28, breakout 4x 25GbE, BGP/EVPN/MLAG | Rede redundante |
| OOB Switch | Switch 48x 1GbE + 4x 10GbE uplink, VLAN isolada | Management/IPMI |

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
        │ 32x100GbE │           │ 32x100GbE │
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
5. **Hardware de tier reduzido**: CPUs e RAM de menor capacidade para custo-benefício sem comprometer funcionalidade
6. **Single cell**: Simplifica operação do lab sem perder cobertura de testes
7. **Host aggregates para overcommit**: Replica modelo de ofertas de produção (shared/dedicated)
8. **Requisitos agnósticos de marca**: Especificação baseada em capabilities permite múltiplos fornecedores

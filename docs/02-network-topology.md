# 02 - Topologia de Rede

## Arquitetura Spine-Leaf

```
                    ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
                    │ Spine-01 │  │ Spine-02 │  │ Spine-03 │  │ Spine-04 │
                    │ AS 65000 │  │ AS 65000 │  │ AS 65000 │  │ AS 65000 │
                    └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘
                         │              │              │              │
         ┌───────────────┼──────────────┼──────────────┼──────────────┤
         │               │              │              │              │
    ┌────┴────┐     ┌────┴────┐    ┌────┴────┐   ┌────┴────┐   ┌────┴────┐
    │Leaf-R1-A│     │Leaf-R1-B│    │Leaf-R2-A│   │Leaf-R2-B│   │  ...    │
    │AS 65001 │     │AS 65001 │    │AS 65002 │   │AS 65002 │   │         │
    └────┬────┘     └────┬────┘    └────┬────┘   └────┬────┘   └─────────┘
         │               │              │              │
         └───────┬───────┘              └──────┬───────┘
                 │ MLAG                        │ MLAG
         ┌───────┴───────┐              ┌──────┴───────┐
         │  Rack 1 Hosts │              │  Rack 2 Hosts│
         └───────────────┘              └──────────────┘
```

## BGP Design

### ASN Allocation

| Dispositivo | ASN | Tipo |
|-------------|-----|------|
| Spine-01..04 | 65000 | iBGP entre Spines |
| Leaf-R1-A/B | 65001 | eBGP para Spines |
| Leaf-R2-A/B | 65002 | eBGP para Spines |
| Leaf-R3-A/B | 65003 | eBGP para Spines |
| Leaf-R4-A/B | 65004 | eBGP para Spines |
| Leaf-R5-A/B | 65005 | eBGP para Spines |
| Leaf-R6-A/B | 65006 | eBGP para Spines |
| Leaf-R7-A/B | 65007 | eBGP para Spines |
| Leaf-R8-A/B | 65008 | eBGP para Spines |
| Leaf-R9-A/B | 65009 | eBGP para Spines |

### EVPN Overlay

- **Type-2**: MAC/IP advertisement (VM mobility)
- **Type-5**: IP Prefix routes (inter-subnet routing)
- **VNI Range**: 10000-19999 (tenant networks)
- **VNI para VLANs de infra**: 1001-1099

## Segmentação de Rede (VLANs/VXLANs)

### VLANs de Infraestrutura

| VLAN ID | Nome | Subnet | Função |
|---------|------|--------|--------|
| 10 | MGMT | 10.0.10.0/24 | Management/API |
| 11 | MGMT-AZ2 | 10.0.11.0/24 | Management AZ2 |
| 12 | MGMT-AZ3 | 10.0.12.0/24 | Management AZ3 |
| 20 | STORAGE | 10.0.20.0/24 | Storage replication |
| 21 | STORAGE-AZ2 | 10.0.21.0/24 | Storage AZ2 |
| 22 | STORAGE-AZ3 | 10.0.22.0/24 | Storage AZ3 |
| 30 | TENANT-VXLAN | 10.0.30.0/24 | VXLAN tunnel endpoints |
| 31 | TENANT-AZ2 | 10.0.31.0/24 | VXLAN AZ2 |
| 32 | TENANT-AZ3 | 10.0.32.0/24 | VXLAN AZ3 |
| 40 | EXTERNAL | 203.0.113.0/24 | Provider/External |
| 50 | OOB | 172.16.0.0/24 | Out-of-Band/IPMI |
| 60 | PXE | 172.16.1.0/24 | PXE Boot/Provisioning |
| 100 | INTERNAL-API | 10.0.100.0/24 | OpenStack internal API |
| 200 | DB-REPL | 10.0.200.0/24 | Galera/RabbitMQ cluster |

### Redes OpenStack (Neutron)

| Tipo | Segmentação | Range | Uso |
|------|-------------|-------|-----|
| Provider | VLAN 40 | 203.0.113.0/24 | Floating IPs, External |
| Tenant Overlay | VXLAN VNI 10000-19999 | 10.x.x.x/24 (auto) | VM networks |
| Provider Flat | Untagged | 192.168.0.0/16 | Bare metal (Ironic) |

## Endereçamento IP

### Management Network (VLAN 10)

| Host | IP | Função |
|------|----|--------|
| lb-vip | 10.0.10.5 | HAProxy VIP (Keepalived) |
| ctrl-az1fd1-01 | 10.0.10.11 | Controller 1 |
| ctrl-az2fd1-01 | 10.0.10.12 | Controller 2 |
| ctrl-az3fd1-01 | 10.0.10.13 | Controller 3 |
| db-az1fd1-01 | 10.0.10.21 | MariaDB 1 |
| db-az2fd1-01 | 10.0.10.22 | MariaDB 2 |
| db-az3fd1-01 | 10.0.10.23 | MariaDB 3 |
| mq-az1fd1-01 | 10.0.10.31 | RabbitMQ 1 |
| mq-az2fd1-01 | 10.0.10.32 | RabbitMQ 2 |
| mq-az3fd1-01 | 10.0.10.33 | RabbitMQ 3 |
| compute-az1fd1-01..12 | 10.0.10.101-112 | Compute AZ1-FD1 |
| compute-az1fd2-01..12 | 10.0.10.113-124 | Compute AZ1-FD2 |
| compute-az1fd3-01..12 | 10.0.10.125-136 | Compute AZ1-FD3 |

### Storage Network (VLAN 20)

| Host | IP | Função |
|------|----|--------|
| swift-az1fd1-01 | 10.0.20.101 | Swift node 1 |
| swift-az1fd1-02 | 10.0.20.102 | Swift node 2 |
| cinder-az1fd1-01 | 10.0.20.201 | Cinder volume |

### VIP Addresses

| Serviço | VIP | Port |
|---------|-----|------|
| Keystone Public | 10.0.10.5 | 5000 |
| Keystone Admin | 10.0.100.5 | 5000 |
| Nova API | 10.0.10.5 | 8774 |
| Neutron API | 10.0.10.5 | 9696 |
| Glance API | 10.0.10.5 | 9292 |
| Cinder API | 10.0.10.5 | 8776 |
| Swift Proxy | 10.0.10.5 | 8080 |
| Horizon | 10.0.10.5 | 443 |
| Heat API | 10.0.10.5 | 8004 |
| Octavia API | 10.0.10.5 | 9876 |
| Barbican API | 10.0.10.5 | 9311 |
| Designate API | 10.0.10.5 | 9001 |
| Placement API | 10.0.10.5 | 8778 |
| MariaDB | 10.0.200.5 | 3306 |
| RabbitMQ | 10.0.200.6 | 5672 |

## Interface Bonding (Host)

```
┌─────────────────────────────────────────────────┐
│                    Host                          │
│                                                  │
│  bond0 (LACP 802.3ad)          bond1 (LACP)    │
│  ├── ens1f0 (Leaf-A)           ├── ens2f0       │
│  └── ens1f1 (Leaf-B)           └── ens2f1       │
│       │                              │           │
│  VLAN 10: Management           VLAN 30: Tunnel  │
│  VLAN 20: Storage              VLAN 40: External│
│  VLAN 100: Internal API                         │
│  VLAN 200: DB Replication                       │
└─────────────────────────────────────────────────┘
```

### Bond Configuration

- **Mode**: 802.3ad (LACP)
- **Hash**: layer3+4
- **MLAG**: Leaf-A e Leaf-B formam MLAG pair
- **MTU**: 9000 (Jumbo Frames) em todas as interfaces de dados
- **MTU**: 1500 para Management e OOB

## Fluxos de Tráfego

### North-South (VM → Internet)

```
VM → br-int → OVN Logical Router → Gateway Chassis (net-XX) → br-ex → VLAN 40 → Spine → Border Router
```

### East-West (VM → VM, mesmo tenant)

```
VM-A → br-int → Geneve tunnel (VLAN 30) → br-int → VM-B
```

### Storage (Compute → Cinder)

```
Compute → bond0.20 (VLAN 20) → Leaf → Cinder Node (iSCSI/NVMe-oF)
```

### Replication (Galera/RabbitMQ)

```
DB-01 → bond0.200 (VLAN 200) → Leaf → Spine → Leaf → DB-02
```

## MTU Matrix

| Rede | MTU | Justificativa |
|------|-----|---------------|
| Management (VLAN 10) | 1500 | Compatibilidade |
| Storage (VLAN 20) | 9000 | Performance iSCSI/NFS |
| Tunnel (VLAN 30) | 9000 | Overhead VXLAN (50 bytes) |
| External (VLAN 40) | 1500 | Internet standard |
| OOB (VLAN 50) | 1500 | IPMI standard |
| Internal API (VLAN 100) | 9000 | Performance inter-service |
| DB Replication (VLAN 200) | 9000 | Galera SST/IST |

## Segurança de Rede

### Microsegmentação

- ACLs por VLAN nos Leaf switches
- Security Groups via OVN (stateful firewall por VM)
- Isolamento total entre tenant networks (VXLAN)
- Management network não acessível de tenant networks

### Proteções

- DHCP Snooping em VLANs de tenant
- Dynamic ARP Inspection
- IP Source Guard
- Storm Control (broadcast/multicast limiting)
- BFD (Bidirectional Forwarding Detection) em todas as sessões BGP

## Decisões Arquiteturais

1. **eBGP Spine-Leaf**: Simplicidade operacional, cada leaf é AS independente
2. **EVPN/VXLAN**: Escalabilidade de L2 sem STP, suporte a VM mobility
3. **MLAG nos Leafs**: Redundância ativa-ativa sem perda de bandwidth
4. **Jumbo Frames (9000)**: Reduz overhead de CPU para tráfego de storage
5. **Separação bond0/bond1**: Isolamento físico entre management/storage e tenant/external
6. **OVN como SDN**: Distributed routing, nativo no OpenStack, sem controlador externo

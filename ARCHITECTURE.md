# OpenStack - Documentação Arquitetural Enterprise

**Autor:** Arquiteto Sênior de Cloud Infrastructure  
**Data:** 2026-05-08  
**Escopo:** Análise dos 12 componentes core do ecossistema OpenStack  
**Repositório:** `C:\Users\Heitor Rapcinski\Code\GitHub\openstack`

---

## 1. Visão Geral da Plataforma

OpenStack é uma plataforma de cloud computing open-source composta por serviços modulares que controlam pools de computação, armazenamento e rede em um datacenter. A arquitetura segue o padrão **shared-nothing** com comunicação via APIs REST e message broker (RabbitMQ/AMQP).

### 1.1 Princípios Arquiteturais

| Princípio | Implementação |
|-----------|---------------|
| Loosely Coupled | Cada serviço é independente, comunicação via REST + AMQP |
| Shared Nothing | Sem estado compartilhado entre workers; estado em DB + message queue |
| Plugin Architecture | Stevedore entry_points para drivers/backends intercambiáveis |
| API-First | Todas as operações expostas via REST APIs versionadas |
| Eventually Consistent | Modelo de consistência eventual entre serviços |
| Horizontal Scalability | Workers stateless permitem scale-out linear |

### 1.2 Stack Tecnológico Comum

- **Linguagem:** Python 3.10+ (CPython)
- **Build System:** pbr (Python Build Reasonableness) + pyproject.toml
- **WSGI:** PasteDeploy, Pecan, Flask (varia por serviço)
- **ORM:** SQLAlchemy + Alembic (migrações)
- **Message Queue:** oslo.messaging (RabbitMQ/Kafka)
- **Cache:** oslo.cache (dogpile.cache + memcached/Redis)
- **Configuração:** oslo.config (INI files)
- **Políticas:** oslo.policy (RBAC baseado em JSON/YAML)
- **Logging:** oslo.log (structured logging)
- **Licença:** Apache 2.0

### 1.3 Mapa de Dependências Inter-Serviços

```
                    ┌─────────────┐
                    │  KEYSTONE   │ ◄── Todos os serviços autenticam aqui
                    │  (Identity) │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────────┐
        │                  │                      │
   ┌────▼────┐      ┌─────▼─────┐         ┌─────▼─────┐
   │  NOVA   │◄────►│  NEUTRON  │◄───────►│  OCTAVIA  │
   │(Compute)│      │(Networking)│         │  (LBaaS)  │
   └────┬────┘      └─────┬─────┘         └───────────┘
        │                  │
   ┌────▼────┐      ┌─────▼─────┐
   │ GLANCE  │      │ DESIGNATE │
   │ (Image) │      │  (DNSaaS) │
   └────┬────┘      └───────────┘
        │
   ┌────▼────┐      ┌───────────┐         ┌───────────┐
   │ CINDER  │◄────►│ BARBICAN  │◄───────►│  IRONIC   │
   │ (Block) │      │(Key Mgmt) │         │(Bare Metal)│
   └─────────┘      └───────────┘         └───────────┘

   ┌─────────┐      ┌───────────┐         ┌───────────┐
   │  SWIFT  │      │  MAGNUM   │◄───────►│    ZUN    │
   │(Object) │      │(Container │         │(Containers)│
   └─────────┘      │  Orch.)   │         └───────────┘
                    └───────────┘
```

---

## 2. Componentes Core

### 2.1 KEYSTONE — Identity Service

| Atributo | Valor |
|----------|-------|
| **Função** | Autenticação, Autorização, Catálogo de Serviços, Federação |
| **Python** | >=3.10 |
| **Framework** | Flask + Flask-RESTful |
| **DB** | SQLAlchemy (MySQL/PostgreSQL) |
| **Token Provider** | Fernet (default), JWS |
| **Identity Backend** | SQL (default), LDAP |

**Processos:**
- `keystone-manage` — Administração (bootstrap, db_sync, fernet_setup, credential_setup)
- `keystone-status` — Verificação de upgrade

**Arquitetura Interna:**
```
keystone/
├── api/              # REST API (Flask blueprints)
├── auth/             # Plugins de autenticação (password, token, totp, oauth1, mapped)
├── assignment/       # Role assignments
├── catalog/          # Service catalog
├── credential/       # Credential encryption
├── federation/       # SAML2, OIDC, Mapped identity
├── identity/         # User/Group management (SQL, LDAP backends)
├── policy/           # Policy engine
├── resource/         # Projects, Domains
├── token/            # Token issuance/validation (Fernet, JWS)
└── trust/            # Trust delegation
```

**Integrações Críticas:**
- Todos os serviços OpenStack dependem do Keystone para autenticação via `keystonemiddleware`
- Suporte a federação (SAML2, OpenID Connect) para SSO enterprise
- Token Fernet: simétrico, sem persistência em DB, rotação de chaves

**Considerações HA:**
- Stateless (tokens Fernet não requerem DB lookup)
- Deploy atrás de HAProxy/Nginx com múltiplas instâncias
- Fernet key rotation requer sincronização entre nós (rsync/shared storage)
- Cache de tokens via dogpile.cache + memcached cluster



---

### 2.2 NOVA — Compute Service

| Atributo | Valor |
|----------|-------|
| **Função** | Gerenciamento do ciclo de vida de VMs (provisioning, scheduling, live migration) |
| **Python** | >=3.11 |
| **Framework** | PasteDeploy + Routes (WSGI nativo) |
| **DB** | SQLAlchemy (cell databases + API database) |
| **Hypervisors** | libvirt/KVM (principal), VMware, Hyper-V, Ironic (bare metal) |
| **Scheduler** | Filter/Weight-based com Placement API |

**Processos (11 binários):**
- `nova-api` — REST API (via WSGI)
- `nova-compute` — Gerencia hypervisor local
- `nova-conductor` — Proxy DB para compute nodes (segurança)
- `nova-scheduler` — Placement-aware scheduling
- `nova-novncproxy` / `nova-spicehtml5proxy` / `nova-serialproxy` — Console proxies
- `nova-manage` — Administração
- `nova-status` — Verificação de upgrade

**Arquitetura Interna:**
```
nova/
├── api/              # REST API v2.1 (microversioned)
├── compute/          # Compute manager, resource tracker
├── conductor/        # DB proxy, migration orchestration
├── scheduler/        # Filter scheduler + Placement integration
├── virt/             # Hypervisor drivers (libvirt, vmwareapi, ironic, fake)
├── network/          # Network abstraction (Neutron integration)
├── objects/          # Versioned objects (RPC compatibility)
├── db/               # SQLAlchemy models + migrations
├── pci/              # PCI passthrough management
├── volume/           # Cinder integration (attach/detach)
└── image/            # Glance integration
```

**Padrão Cell v2:**
```
┌─────────────────────────────────────────────┐
│              API Database                    │
│  (instance mappings, cell mappings)          │
├─────────────────────────────────────────────┤
│           nova-api + nova-conductor          │
├──────────┬──────────────┬───────────────────┤
│  Cell 0  │    Cell 1    │     Cell N        │
│(scheduler│ (compute DB  │  (compute DB      │
│  only)   │  + MQ + nodes│   + MQ + nodes)   │
└──────────┴──────────────┴───────────────────┘
```

**Integrações Críticas:**
- **Placement API** — Resource inventory/allocation (separado desde Stein)
- **Neutron** — Port binding, security groups, floating IPs
- **Glance** — Image download para hypervisor
- **Cinder** — Volume attach/detach via os-brick
- **Keystone** — AuthN/AuthZ
- **Barbican** — Encryption keys para volumes/vtpm

**Considerações HA:**
- Cell architecture permite escalar para 10k+ compute nodes
- nova-conductor elimina acesso direto ao DB dos compute nodes
- Live migration com convergência automática
- Evacuate para failover de compute nodes

---

### 2.3 NEUTRON — Networking Service

| Atributo | Valor |
|----------|-------|
| **Função** | SDN — redes virtuais, subnets, routers, security groups, LBaaS, VPNaaS |
| **Python** | >=3.10 |
| **Framework** | Pecan (REST) + PasteDeploy |
| **DB** | SQLAlchemy (MySQL/PostgreSQL) |
| **Backend Principal** | ML2 + OVN (default moderno) / OVS |
| **Agents** | L3, DHCP, Metadata, OVS, SRIOV, OVN |

**Processos (30 binários):**
- `neutron-server` (via neutron-rpc-server) — API + RPC server
- `neutron-dhcp-agent` — DHCP (dnsmasq)
- `neutron-l3-agent` — Routing, NAT, Floating IPs
- `neutron-metadata-agent` — Instance metadata proxy
- `neutron-openvswitch-agent` — OVS dataplane
- `neutron-ovn-agent` — OVN dataplane
- `neutron-sriov-nic-agent` — SR-IOV
- `neutron-metering-agent` — Traffic metering
- `neutron-linuxbridge-agent` — LinuxBridge dataplane

**Arquitetura ML2 (Modular Layer 2):**
```
┌─────────────────────────────────────────────┐
│              Neutron Server                  │
├─────────────────────────────────────────────┤
│           ML2 Core Plugin                   │
├──────────┬──────────────┬───────────────────┤
│Type      │ Mechanism    │ Extension         │
│Drivers   │ Drivers      │ Drivers           │
│(flat,vlan│(ovn,ovs,     │(port_security,    │
│ vxlan,   │ sriov,       │ qos, dns,         │
│ geneve,  │ l2population,│ data_plane_status)│
│ gre)     │ macvtap)     │                   │
└──────────┴──────────────┴───────────────────┘
```

**Service Plugins:**
- Router (L3), QoS, Trunk, Port Forwarding, Metering, Tag
- OVN Router (distributed routing nativo)
- Segments, Network IP Availability

**Integrações Críticas:**
- **Nova** — Port binding durante boot de instância
- **Octavia** — Load balancer provisioning
- **Designate** — DNS integration para ports/floating IPs
- **Ironic** — Bare metal networking (flat/VLAN)
- **OVN/OVS** — Dataplane (southbound)

**Considerações HA:**
- OVN: distributed routing elimina L3 agent SPOF
- DVR (Distributed Virtual Router) para OVS
- DHCP agent: múltiplos agentes por rede
- Metadata agent: co-located com router namespace
- ML2/OVN é o backend recomendado para produção (sem agents tradicionais)



---

### 2.4 GLANCE — Image Service

| Atributo | Valor |
|----------|-------|
| **Função** | Registro e entrega de imagens de disco para VMs |
| **Python** | >=3.11 |
| **Framework** | Routes + WebOb (WSGI nativo) |
| **DB** | SQLAlchemy (MySQL/PostgreSQL) |
| **Storage Backends** | File, Swift, Ceph RBD, S3, VMware Datastore |
| **Import Methods** | web-download, glance-direct, copy-image |

**Processos:**
- `glance-api` — REST API (v2) + image upload/download
- `glance-scrubber` — Delayed delete cleanup
- `glance-cache-*` — Image cache management (prefetcher, pruner, cleaner)
- `glance-manage` — DB sync, administração
- `glance-status` — Verificação de upgrade

**Arquitetura Interna:**
```
glance/
├── api/              # REST API v2 (WSGI)
├── async_/           # Async image import (taskflow-based)
├── common/           # Shared utilities
├── db/               # SQLAlchemy models
├── domain/           # Domain model (Image, ImageMember, Task)
├── image_cache/      # Local image caching
├── notifier/         # oslo.messaging notifications
├── policies/         # RBAC policies
├── quota/            # Image quota enforcement
└── scrubber/         # Delayed delete processing
```

**Image Import Workflow (Interoperable):**
```
Client ──► staging area ──► import task ──► backend store
                                │
                         ┌──────┼──────┐
                         │ Plugins:    │
                         │ - convert   │
                         │ - introspect│
                         │ - decompress│
                         └─────────────┘
```

**Integrações Críticas:**
- **Nova** — Download de imagens para compute nodes
- **Cinder** — Upload de volumes como imagens / criar volumes de imagens
- **Swift** — Backend de armazenamento
- **Barbican/Castellan** — Assinatura e verificação de imagens

**Considerações HA:**
- API stateless, múltiplas instâncias atrás de LB
- Backend Ceph RBD: replicação nativa, sem SPOF
- Image cache local nos compute nodes reduz tráfego
- Interoperable import permite copy-image entre stores (multi-store)

---

### 2.5 CINDER — Block Storage Service

| Atributo | Valor |
|----------|-------|
| **Função** | Volumes persistentes (block devices) para instâncias |
| **Python** | >=3.11 |
| **Framework** | Routes + PasteDeploy (WSGI) |
| **DB** | SQLAlchemy (MySQL/PostgreSQL) |
| **Backends** | LVM (ref.), Ceph RBD, NetApp, Dell EMC, Pure, HPE 3PAR, 100+ drivers |
| **Protocols** | iSCSI, FC, NFS, RBD, NVMe-oF |

**Processos:**
- `cinder-api` — REST API (v3, microversioned)
- `cinder-scheduler` — Volume placement (filter/weight)
- `cinder-volume` — Volume lifecycle (1 por backend)
- `cinder-backup` — Backup to Swift/Ceph/NFS
- `cinder-manage` — Administração
- `cinder-status` — Verificação de upgrade

**Arquitetura Interna:**
```
cinder/
├── api/              # REST API v3 (microversioned)
├── backup/           # Backup drivers (swift, ceph, nfs, google, s3)
├── scheduler/        # Filter scheduler (capacity, capabilities)
├── volume/           # Volume manager + 100+ drivers
│   ├── drivers/      # Storage backend drivers
│   ├── flows/        # Taskflow-based workflows
│   └── targets/      # iSCSI/FC/NVMe target drivers
├── transfer/         # Volume transfer between projects
├── group/            # Consistency groups / generic groups
├── image/            # Glance integration
├── objects/          # Versioned objects
└── zonemanager/      # FC zone management
```

**Scheduler Filters:**
- AvailabilityZoneFilter, CapabilitiesFilter, CapacityFilter
- DriverFilter, JsonFilter, InstanceLocalityFilter

**Integrações Críticas:**
- **Nova** — Volume attach/detach via os-brick
- **Glance** — Volume-backed images, image-to-volume
- **Barbican** — Volume encryption keys (LUKS)
- **Swift/Ceph** — Backup targets
- **Keystone** — Multi-tenancy, policy enforcement

**Considerações HA:**
- Active/Active para cinder-api e cinder-scheduler
- cinder-volume: Active/Passive por backend (lock via tooz/DLM)
- Volume replication (managed/unmanaged) para DR
- Backup incremental para RPO otimizado
- Multi-backend: um cinder-volume por storage array

---

### 2.6 SWIFT — Object Storage Service

| Atributo | Valor |
|----------|-------|
| **Função** | Object storage distribuído, eventualmente consistente, altamente durável |
| **Python** | >=3.7 |
| **Framework** | WSGI nativo (PasteDeploy + middleware pipeline) |
| **DB** | SQLite (per-device) — sem DB centralizado |
| **Replicação** | 3 réplicas (default) ou Erasure Coding |
| **Consistência** | Eventual (replicators + auditors) |

**Processos (40 binários) — Arquitetura por camada:**
```
┌─────────────────────────────────────────────┐
│              Proxy Layer                     │
│  swift-proxy-server (routing, auth, middleware)│
├─────────────────────────────────────────────┤
│           Storage Layer (per-node)           │
│  ┌──────────┬──────────────┬──────────────┐ │
│  │ Account  │  Container   │   Object     │ │
│  │ Server   │  Server      │   Server     │ │
│  │ Auditor  │  Auditor     │   Auditor    │ │
│  │Replicator│ Replicator   │ Replicator   │ │
│  │          │  Updater     │   Updater    │ │
│  │          │  Sharder     │   Expirer    │ │
│  │          │  Sync        │Reconstructor │ │
│  └──────────┴──────────────┴──────────────┘ │
├─────────────────────────────────────────────┤
│              Ring (consistent hashing)       │
│  swift-ring-builder (partition assignment)   │
└─────────────────────────────────────────────┘
```

**Middleware Pipeline (30+ filtros):**
- **Auth:** tempauth, keystoneauth, s3api
- **Funcionalidade:** slo (large objects), dlo, tempurl, formpost, staticweb
- **Performance:** memcache, ratelimit, proxy-logging
- **Segurança:** encryption (at-rest), account_quotas, container_quotas
- **Compatibilidade:** s3api (S3-compatible API)

**Dependências (minimalista — 9 pacotes):**
eventlet, greenlet, PasteDeploy, lxml, requests, xattr, PyECLib, cryptography, dnspython

**Integrações Críticas:**
- **Keystone** — Autenticação via keystoneauth middleware
- **Glance** — Backend de armazenamento de imagens
- **Cinder** — Backup target
- **S3 API** — Compatibilidade com clientes AWS S3

**Considerações HA:**
- **Sem SPOF por design** — dados replicados em 3+ nós/zonas
- Proxy layer: múltiplos proxies atrás de LB
- Ring: consistent hashing garante distribuição uniforme
- Erasure Coding: 1.5x overhead vs 3x (réplicas) para dados cold
- Container Sharding: escala para bilhões de objetos por container
- Sem DB centralizado = sem bottleneck de DB



---

## 3. Serviços de Plataforma

### 3.1 OCTAVIA — Load Balancer as a Service

| Atributo | Valor |
|----------|-------|
| **Função** | Load balancing L4/L7 com alta disponibilidade |
| **Python** | >=3.10 |
| **Framework** | Pecan (API) + Flask (Amphora agent) |
| **DB** | SQLAlchemy (MySQL/PostgreSQL) |
| **Dataplane** | HAProxy (dentro de Amphorae VMs) |
| **HA Mode** | Active/Standby (VRRP) ou Active/Active |

**Processos:**
- `octavia-api` — REST API (v2, LBaaS v2 compatible)
- `octavia-worker` — Provisioning workflows (taskflow)
- `octavia-health-manager` — Monitora health das amphorae
- `octavia-housekeeping` — Cleanup de recursos órfãos
- `octavia-driver-agent` — Provider driver interface
- `amphora-agent` — Agent dentro da VM amphora (Flask)
- `prometheus-proxy` — Métricas Prometheus

**Arquitetura Interna:**
```
┌─────────────────────────────────────────────┐
│              Octavia API                     │
├─────────────────────────────────────────────┤
│           Controller Worker                  │
│  (Taskflow-based provisioning)              │
├─────────────────────────────────────────────┤
│         Amphora Driver                       │
│  ┌─────────────────────────────────────┐    │
│  │  Amphora VM (Ubuntu/CentOS)         │    │
│  │  ┌─────────┐  ┌──────────────────┐ │    │
│  │  │HAProxy  │  │ Amphora Agent    │ │    │
│  │  │(dataplane│  │ (REST API local) │ │    │
│  │  └─────────┘  └──────────────────┘ │    │
│  │  ┌─────────┐                       │    │
│  │  │Keepalived│ (VRRP para HA)       │    │
│  │  └─────────┘                       │    │
│  └─────────────────────────────────────┘    │
├─────────────────────────────────────────────┤
│         Health Manager                       │
│  (UDP heartbeat monitoring)                 │
└─────────────────────────────────────────────┘
```

**Provider Drivers:**
- Amphora (default — HAProxy em VM)
- OVN (lightweight L4 via OVN load balancer)
- Vendor drivers (F5, A10, etc.)

**Integrações Críticas:**
- **Neutron** — Rede para amphorae (lb-mgmt-net)
- **Nova** — Criação de VMs amphora
- **Glance** — Imagem amphora
- **Barbican** — TLS certificates (TERMINATED_HTTPS)
- **Keystone** — AuthN/AuthZ

**Considerações HA:**
- Amphorae em Active/Standby com VRRP failover (<10s)
- Health manager detecta falhas e triggers failover
- Spare pool de amphorae pré-provisionadas (fast failover)
- Anti-affinity: amphorae HA em compute nodes diferentes

---

### 3.2 DESIGNATE — DNS as a Service

| Atributo | Valor |
|----------|-------|
| **Função** | Gerenciamento de zonas DNS e recordsets via API |
| **Python** | >=3.11 |
| **Framework** | Pecan + Flask |
| **DB** | SQLAlchemy (MySQL/PostgreSQL) |
| **DNS Backends** | BIND9, PowerDNS, Infoblox, Akamai, Designate (built-in) |
| **Configuração** | pyproject.toml (formato moderno) |

**Processos:**
- `designate-api` — REST API (v2)
- `designate-central` — Business logic, validação
- `designate-worker` — Propagação para DNS backends
- `designate-producer` — Periodic tasks (zone polling, delayed NOTIFY)
- `designate-mdns` — Mini DNS server (AXFR/IXFR para backends)
- `designate-sink` — Event listener (Nova/Neutron notifications → DNS records)
- `designate-manage` — Administração

**Arquitetura Interna:**
```
designate/
├── api/              # REST API v2
├── backend/          # DNS server backends (bind9, pdns4, infoblox, akamai)
├── central/          # Core business logic
├── mdns/             # Mini DNS (zone transfers)
├── notification_handler/ # Nova/Neutron event → DNS record
├── objects/          # Versioned objects (Zone, RecordSet, Record)
├── producer/         # Periodic tasks
├── scheduler/        # Zone assignment to pools
├── sink/             # Notification consumer
├── storage/          # DB layer
└── worker/           # Backend propagation
```

**DNS Pool Architecture:**
```
┌──────────────┐     ┌──────────────┐
│ designate-api│────►│designate-    │
└──────────────┘     │central       │
                     └──────┬───────┘
                            │
                     ┌──────▼───────┐
                     │designate-    │
                     │worker        │
                     └──────┬───────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
        ┌─────▼────┐ ┌─────▼────┐ ┌─────▼────┐
        │  BIND9   │ │ PowerDNS │ │ BIND9    │
        │ (pool 1) │ │ (pool 2) │ │ (pool 1) │
        └──────────┘ └──────────┘ └──────────┘
```

**Integrações Críticas:**
- **Neutron** — Automatic DNS records para ports/floating IPs
- **Nova** — Instance hostname → DNS record (via sink)
- **Keystone** — Multi-tenancy (zones per project)

**Considerações HA:**
- Múltiplos workers para propagação paralela
- DNS pools com múltiplos nameservers (anycast)
- mdns: zone transfer para backends (AXFR/IXFR)
- Producer: leader election via tooz para periodic tasks

---

### 3.3 BARBICAN — Key Management Service

| Atributo | Valor |
|----------|-------|
| **Função** | Armazenamento seguro de secrets, chaves, certificados |
| **Python** | >=3.9 |
| **Framework** | Pecan (REST API) |
| **DB** | SQLAlchemy (MySQL/PostgreSQL) |
| **Crypto Backends** | Simple Crypto (default), PKCS#11 HSM, Vault, KMIP |
| **WSGI** | barbican-wsgi-api (único serviço com wsgi_script explícito) |

**Processos:**
- `barbican-api` (ou `barbican-wsgi-api`) — REST API
- `barbican-worker` — Async task processing (certificate orders)
- `barbican-keystone-listener` — Keystone event consumer (project delete → secret cleanup)
- `barbican-retry` — Retry scheduler para tasks falhadas
- `barbican-manage` / `barbican-db-manage` — Administração
- `pkcs11-kek-rewrap` / `pkcs11-key-generation` — HSM key management

**Arquitetura Interna:**
```
barbican/
├── api/              # REST API (Pecan)
│   └── controllers/  # Secrets, Orders, Containers, CAs, Consumers
├── cmd/              # Entry points
├── common/           # Shared utilities, validators
├── model/            # SQLAlchemy models
├── objects/          # Versioned objects
├── plugin/           # Crypto/Secret store plugins
│   ├── crypto/       # Encryption plugins (simple_crypto, p11_crypto)
│   ├── interface/    # Plugin interfaces
│   └── store/        # Secret store backends (vault, kmip)
├── queue/            # Async task queue (oslo.messaging)
└── tasks/            # Certificate issuance, key generation
```

**Secret Types:**
- Symmetric keys, Asymmetric keys (RSA, DSA, EC)
- Certificates (X.509), Certificate Requests (PKCS#10)
- Opaque secrets (passwords, tokens)
- Passphrases

**Integrações Críticas:**
- **Nova** — Encryption keys para ephemeral disks, vTPM
- **Cinder** — Volume encryption keys (LUKS)
- **Octavia** — TLS certificates para HTTPS listeners
- **Glance** — Image signature verification keys
- **Castellan** — Abstraction layer (todos os serviços usam castellan → barbican)
- **Magnum** — TLS certificates para clusters Kubernetes

**Considerações HA:**
- API stateless, múltiplas instâncias
- HSM: PKCS#11 com HA (Luna, Thales, SoftHSM para dev)
- Key encryption key (KEK) wrapping para proteção em repouso
- Keystone listener garante cleanup de secrets em project delete
- Soft delete + crypto shredding para compliance



---

### 3.4 IRONIC — Bare Metal Provisioning

| Atributo | Valor |
|----------|-------|
| **Função** | Provisioning de servidores físicos (bare metal) como se fossem VMs |
| **Python** | >=3.10 |
| **Framework** | Pecan (REST API) |
| **DB** | SQLAlchemy (MySQL/PostgreSQL) |
| **Boot Methods** | PXE, iPXE, Virtual Media, HTTP Boot |
| **Management** | IPMI, Redfish, iDRAC, iLO, SNMP |
| **Configuração** | pyproject.toml (formato moderno) |

**Processos:**
- `ironic-api` — REST API (microversioned)
- `ironic-conductor` — Node lifecycle management (deploy, clean, inspect)
- `ironic` — Single-process mode (API + conductor)
- `ironic-pxe-filter` — DHCP filtering para PXE boot
- `ironic-dbsync` — DB migrations
- `ironic-status` — Verificação de upgrade

**Arquitetura Interna:**
```
ironic/
├── api/              # REST API (Pecan, microversioned)
├── conductor/        # Node state machine, deploy orchestration
├── drivers/          # Hardware drivers (composable)
│   ├── modules/      # Driver interfaces implementation
│   │   ├── bios/     # BIOS configuration
│   │   ├── boot/     # PXE, iPXE, virtual media
│   │   ├── console/  # Serial console (shellinabox, socat)
│   │   ├── deploy/   # Direct deploy, Ansible deploy
│   │   ├── inspect/  # Hardware inspection
│   │   ├── management/ # IPMI, Redfish, iDRAC, iLO
│   │   ├── network/  # Neutron flat/VLAN
│   │   ├── power/    # Power on/off/reboot
│   │   ├── raid/     # RAID configuration
│   │   └── storage/  # Storage configuration
├── dhcp/             # DHCP provider (Neutron)
├── objects/          # Versioned objects (Node, Port, Portgroup)
└── pxe_filter/       # DHCP request filtering
```

**Node State Machine:**
```
enroll → manageable → available → active
                  ↕                    ↕
              inspecting          deploying
                                      ↕
                                  deploy wait
                                      ↕
                                   active
                                      ↕
                                  deleting
                                      ↕
                                  cleaning
```

**Driver Composition (Hardware Types):**
```
hardware_type = ipmi
├── boot: pxe, ipxe, http
├── console: ipmitool-socat
├── deploy: direct, ramdisk
├── inspect: inspector, no-inspect
├── management: ipmitool
├── network: neutron, flat, noop
├── power: ipmitool
├── raid: agent, no-raid
└── storage: noop, cinder
```

**Integrações Críticas:**
- **Nova** — Ironic como virt driver (bare metal = flavor)
- **Neutron** — Network provisioning (VLAN switching)
- **Glance** — Deploy images
- **Swift** — Temporary URLs para image download
- **Keystone** — AuthN/AuthZ
- **Inspector** — Hardware introspection (ironic-inspector)

**Considerações HA:**
- Múltiplos conductors com hash ring (consistent hashing)
- Cada conductor gerencia subset de nodes
- Conductor failover: nodes redistribuídos automaticamente
- IPMI/Redfish: out-of-band management (independente do OS)
- Cleaning: secure erase entre tenants (compliance)

---

### 3.5 MAGNUM — Container Infrastructure Management

| Atributo | Valor |
|----------|-------|
| **Função** | Provisionamento de clusters Kubernetes/Docker Swarm/Mesos |
| **Python** | >=3.11 |
| **Framework** | Pecan + WSME (REST API) |
| **DB** | SQLAlchemy (MySQL/PostgreSQL) |
| **Orchestration** | Heat templates (default) ou CAPI (Cluster API) |
| **COE Suportados** | Kubernetes (principal), Docker Swarm, Mesos |

**Processos:**
- `magnum-api` — REST API
- `magnum-conductor` — Cluster lifecycle (create, update, delete, scale)
- `magnum-db-manage` — DB migrations
- `magnum-driver-manage` — List available drivers
- `magnum-status` — Verificação de upgrade

**Arquitetura Interna:**
```
magnum/
├── api/              # REST API (Pecan + WSME)
├── cmd/              # Entry points
├── common/           # Shared utilities, x509 cert generation
├── conductor/        # Cluster lifecycle orchestration
├── conf/             # oslo.config definitions
├── db/               # SQLAlchemy models (Cluster, ClusterTemplate, NodeGroup)
├── drivers/          # COE drivers
│   ├── heat/         # Heat-based drivers (k8s, swarm, mesos)
│   └── common/      # Shared driver utilities
├── objects/          # Versioned objects
└── service/          # Service utilities
```

**Cluster Provisioning Flow:**
```
magnum-api ──► magnum-conductor ──► Heat Stack Create
                                         │
                                    ┌────▼────┐
                                    │ Nova VMs │
                                    │(masters +│
                                    │ workers) │
                                    └────┬────┘
                                         │
                                    ┌────▼────┐
                                    │cloud-init│
                                    │+ scripts │
                                    │(kubeadm) │
                                    └─────────┘
```

**Integrações Críticas:**
- **Heat** — Orchestration de infraestrutura (VMs, networks, LBs)
- **Nova** — VMs para master/worker nodes
- **Neutron** — Cluster networking (Flannel, Calico, Kuryr)
- **Cinder** — Persistent volumes para containers
- **Octavia** — Load balancer para Kubernetes API
- **Barbican** — TLS certificates para cluster PKI
- **Keystone** — Multi-tenancy, cloud-provider integration

**Considerações HA:**
- Kubernetes masters em HA (3+ masters com etcd cluster)
- Octavia LB na frente do Kubernetes API server
- Node groups para scale-out de workers
- Rolling upgrades de clusters
- Cluster auto-healing (node replacement)

---

### 3.6 ZUN — Container Service

| Atributo | Valor |
|----------|-------|
| **Função** | Execução de containers diretamente na API OpenStack (sem cluster) |
| **Python** | >=3.8 |
| **Framework** | Pecan (REST API) |
| **DB** | SQLAlchemy (MySQL/PostgreSQL) |
| **Container Runtime** | Docker (principal), CRI (containerd/CRI-O via gRPC) |
| **Networking** | Kuryr (Neutron-native container networking) |
| **WSGI** | zun-api-wsgi (entry point explícito) |

**Processos:**
- `zun-api` (ou `zun-api-wsgi`) — REST API
- `zun-compute` — Container lifecycle no host
- `zun-wsproxy` — WebSocket proxy (attach/exec)
- `zun-cni` / `zun-cni-daemon` — CNI plugin (Kuryr integration)
- `zun-db-manage` — DB migrations
- `zun-status` — Verificação de upgrade

**Arquitetura Interna:**
```
zun/
├── api/              # REST API (Pecan)
├── cmd/              # Entry points
├── cni/              # CNI plugin (Kuryr-based networking)
├── common/           # Shared utilities
├── compute/          # Container manager (Docker/CRI driver)
├── container/        # Container runtime drivers
│   ├── docker/       # Docker driver (docker-py)
│   └── cri/          # CRI driver (gRPC → containerd)
├── criapi/           # CRI API protobuf definitions
├── image/            # Image drivers (Docker Hub, Glance)
├── network/          # Network drivers (Kuryr, Docker native)
├── objects/          # Versioned objects (Container, Capsule, Host)
├── pci/              # PCI passthrough para containers
├── scheduler/        # Container placement (filter/weight)
├── volume/           # Cinder volume attach para containers
└── websocket/        # WebSocket proxy (exec/attach)
```

**Container Lifecycle:**
```
zun-api ──► zun-scheduler ──► zun-compute
                                    │
                              ┌─────▼─────┐
                              │  Docker /  │
                              │ containerd │
                              └─────┬─────┘
                                    │
                              ┌─────▼─────┐
                              │   Kuryr    │
                              │(Neutron CNI)│
                              └───────────┘
```

**Capsules (Pod-like):**
- Grupo de containers com shared network namespace
- Similar a Kubernetes Pods
- Definição via YAML (compatível com k8s pod spec subset)

**Integrações Críticas:**
- **Neutron/Kuryr** — Container networking nativo OpenStack
- **Cinder** — Persistent volumes para containers
- **Glance** — Image registry alternativo
- **Nova** — Compartilha compute hosts (co-scheduling)
- **Keystone** — AuthN/AuthZ
- **os-vif** — Virtual interface management

**Considerações HA:**
- zun-compute: 1 por host (gerencia containers locais)
- Scheduler: filter-based (similar a Nova)
- Container restart policies (always, on-failure)
- Health checks integrados
- PCI passthrough para GPU containers



---

## 4. Padrões Arquiteturais Transversais

### 4.1 Comunicação Inter-Serviços

| Padrão | Uso | Tecnologia |
|--------|-----|------------|
| REST API (síncrono) | Client → Service | WSGI + keystoneauth1 |
| RPC (assíncrono) | Service → Service (interno) | oslo.messaging (RabbitMQ) |
| Notifications (pub/sub) | Events broadcast | oslo.messaging (fanout) |
| Callback | Long-running tasks | Taskflow + polling |

### 4.2 Padrão de Microserviço OpenStack

```
┌─────────────────────────────────────────────────────┐
│                    Service X                         │
├─────────────────────────────────────────────────────┤
│  x-api          │ REST API (WSGI)                   │
│  x-conductor    │ DB proxy / orchestration          │
│  x-scheduler    │ Placement / resource selection    │
│  x-worker       │ Backend operations                │
│  x-manage       │ CLI administration                │
│  x-status       │ Upgrade check (oslo.upgradecheck) │
├─────────────────────────────────────────────────────┤
│  oslo.config    │ Configuration (INI)               │
│  oslo.policy    │ RBAC (policy.yaml)                │
│  oslo.db        │ Database (SQLAlchemy + Alembic)   │
│  oslo.messaging │ RPC + Notifications               │
│  oslo.log       │ Structured logging                │
│  oslo.cache     │ Caching (memcached/Redis)         │
│  stevedore      │ Plugin loading (entry_points)     │
└─────────────────────────────────────────────────────┘
```

### 4.3 Versioned Objects (oslo.versionedobjects)

Todos os serviços usam objetos versionados para RPC, permitindo:
- Rolling upgrades (conductor novo fala com compute antigo)
- Backward compatibility via object version negotiation
- Serialização/deserialização automática

### 4.4 Database Migrations

- **Alembic** para migrações incrementais
- Padrão expand/contract para zero-downtime upgrades:
  1. **Expand:** adiciona colunas/tabelas (backward compatible)
  2. **Migrate data:** popula novos campos
  3. **Contract:** remove colunas/tabelas antigas

---

## 5. Segurança Enterprise

### 5.1 Modelo de Autenticação

```
Client ──► Keystone (token request)
       ◄── Token (Fernet/JWS)
       ──► Service API + Token
              │
              ▼
       keystonemiddleware (token validation)
              │
              ▼
       oslo.policy (RBAC check)
```

### 5.2 Controles de Segurança por Camada

| Camada | Controle | Implementação |
|--------|----------|---------------|
| Rede | TLS everywhere | HAProxy/Nginx termination + internal TLS |
| Autenticação | Multi-factor | Keystone (password + TOTP + receipt) |
| Autorização | RBAC granular | oslo.policy (system/project/domain scope) |
| Dados em trânsito | TLS 1.2+ | oslo.middleware (ssl) |
| Dados em repouso | Encryption | Barbican + LUKS (Cinder), Swift encryption |
| Secrets | HSM-backed | Barbican + PKCS#11 (Luna, Thales) |
| Auditoria | CADF events | pycadf + oslo.messaging notifications |
| Isolamento | Namespaces | Neutron (network namespaces, security groups) |
| Compliance | Secure erase | Ironic cleaning, Cinder volume wiping |

### 5.3 Federação e SSO

- SAML2 (Shibboleth, Mellon)
- OpenID Connect (Keycloak, Azure AD, Okta)
- Mapped identities (external IdP → local project/role)
- Application Credentials (service accounts sem password)

---

## 6. Alta Disponibilidade e Disaster Recovery

### 6.1 Topologia HA de Referência

```
┌─────────────────────────────────────────────────────────┐
│                    Load Balancer (HAProxy)               │
│              VIP: api.openstack.internal                 │
├─────────────────────────────────────────────────────────┤
│  Controller Node 1  │  Controller Node 2  │  Controller Node 3  │
│  ┌───────────────┐  │  ┌───────────────┐  │  ┌───────────────┐  │
│  │ All API svcs  │  │  │ All API svcs  │  │  │ All API svcs  │  │
│  │ RabbitMQ      │  │  │ RabbitMQ      │  │  │ RabbitMQ      │  │
│  │ MariaDB/Galera│  │  │ MariaDB/Galera│  │  │ MariaDB/Galera│  │
│  │ Memcached     │  │  │ Memcached     │  │  │ Memcached     │  │
│  └───────────────┘  │  └───────────────┘  │  └───────────────┘  │
├─────────────────────────────────────────────────────────┤
│  Compute Node 1..N  │  Storage Node 1..N  │  Network Node 1..N  │
└─────────────────────────────────────────────────────────┘
```

### 6.2 Estratégias HA por Componente

| Componente | Estratégia | RTO | RPO |
|------------|-----------|-----|-----|
| Keystone | Active/Active (stateless) | <1s | 0 |
| Nova API | Active/Active | <1s | 0 |
| Nova Compute | Evacuate (masakari) | ~60s | 0 (shared storage) |
| Neutron (OVN) | Distributed, no SPOF | <1s | 0 |
| Glance | Active/Active + Ceph | <1s | 0 |
| Cinder API | Active/Active | <1s | 0 |
| Cinder Volume | Active/Passive (DLM) | ~30s | 0 |
| Swift | Replication (3x) | 0 | 0 |
| Octavia | VRRP failover | <10s | 0 |
| Designate | Multi-worker + DNS pools | <5s | 0 |
| Barbican | Active/Active | <1s | 0 |
| Ironic | Hash ring redistribution | ~30s | 0 |
| RabbitMQ | Mirrored queues / Quorum | <10s | 0 |
| MariaDB | Galera Cluster (3 nodes) | <5s | 0 |

### 6.3 Disaster Recovery

- **Cinder:** Volume replication (sync/async) entre sites
- **Swift:** Global cluster (multi-region replication)
- **Glance:** Multi-store com copy-image entre regiões
- **Nova:** Evacuate + shared storage para site failover
- **DB:** Galera + async replication para DR site

---

## 7. Operações e Observabilidade

### 7.1 Comandos de Administração

Todos os serviços seguem o padrão:
- `<service>-manage db_sync` — Migração de banco
- `<service>-status upgrade check` — Verificação pré-upgrade
- `<service>-manage` — Operações administrativas

### 7.2 Monitoramento

| Aspecto | Ferramenta | Integração |
|---------|-----------|------------|
| Métricas | Prometheus/Ceilometer | oslo.metrics, StatsD |
| Logs | ELK/Loki | oslo.log (JSON structured) |
| Tracing | Jaeger/Zipkin | osprofiler |
| Health | HAProxy checks | /healthcheck endpoint |
| Alerting | Alertmanager/Vitrage | Notification bus |

### 7.3 Upgrade Strategy (Rolling)

```
1. Backup databases
2. Run `<service>-status upgrade check` (all services)
3. Update packages (new code)
4. Run `<service>-manage db_sync --expand`
5. Restart services (one at a time, behind LB)
6. Run `<service>-manage db_sync --contract` (after all nodes updated)
7. Verify via tempest smoke tests
```

---

## 8. Matriz Comparativa

| Serviço | Processos | Deps | Python Min | Framework | DB Required | Stateless API |
|---------|-----------|------|-----------|-----------|-------------|---------------|
| Keystone | 2 | ~30 | 3.10 | Flask | Sim | Sim |
| Nova | 11 | ~55 | 3.11 | Routes/WSGI | Sim (cells) | Sim |
| Neutron | 30 | ~50 | 3.10 | Pecan | Sim | Sim |
| Glance | 10 | ~38 | 3.11 | Routes/WSGI | Sim | Sim |
| Cinder | 9 | ~57 | 3.11 | Routes/WSGI | Sim | Sim |
| Swift | 40 | 9 | 3.7 | WSGI nativo | Não (SQLite local) | Sim |
| Octavia | 12 | ~46 | 3.10 | Pecan/Flask | Sim | Sim |
| Designate | 9 | ~37 | 3.11 | Pecan/Flask | Sim | Sim |
| Barbican | 8 | ~27 | 3.9 | Pecan | Sim | Sim |
| Ironic | 8 | ~45 | 3.10 | Pecan | Sim | Sim |
| Magnum | 5 | ~43 | 3.11 | Pecan/WSME | Sim | Sim |
| Zun | 8 | ~45 | 3.8 | Pecan | Sim | Sim |

---

## 9. Recomendações para Deploy Enterprise

### 9.1 Sizing Mínimo (Produção)

| Tier | Controllers | Compute | Storage | Network |
|------|------------|---------|---------|---------|
| Small (< 50 VMs) | 3 | 3-10 | 3 (Ceph) | Shared |
| Medium (50-500 VMs) | 3 | 10-50 | 5+ (Ceph) | 2+ dedicados |
| Large (500+ VMs) | 5+ | 50-500 | 10+ (Ceph) | 3+ dedicados |

### 9.2 Deployment Tools

| Ferramenta | Uso | Complexidade |
|-----------|-----|-------------|
| Kolla-Ansible | Containers (Docker) | Média |
| OpenStack-Ansible | LXC containers | Alta |
| DevStack | Desenvolvimento | Baixa |
| Kayobe | Bare metal + Kolla | Alta |
| Helm (openstack-helm) | Kubernetes-native | Alta |
| Juju Charms | Model-driven | Média |

### 9.3 Checklist de Segurança

- [ ] TLS em todas as APIs (internal + public)
- [ ] Fernet key rotation automatizada (cron)
- [ ] RBAC com scope enforcement (system/domain/project)
- [ ] Security groups default deny
- [ ] Volume encryption habilitado (Barbican + LUKS)
- [ ] Audit logging (CADF) para compliance
- [ ] Network segmentation (management, tenant, storage, API)
- [ ] HSM para Barbican em produção
- [ ] oslo.policy customizado (least privilege)
- [ ] Secure boot para Ironic bare metal nodes

---

*Documento gerado a partir da análise do código-fonte do repositório OpenStack.*  
*Todos os componentes analisados estão em status Production/Stable.*

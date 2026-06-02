# 03 - Design do Control Plane

## Visão Geral

```
┌─────────────────────────────────────────────────────────────────┐
│                     Control Plane                                 │
│                                                                   │
│  ┌─────────┐     ┌──────────────────────────────────────┐       │
│  │ Clients │────►│  HAProxy VIP (10.0.10.5)             │       │
│  └─────────┘     │  Keepalived VRRP                      │       │
│                   └──────┬───────────┬───────────┬───────┘       │
│                          │           │           │               │
│                   ┌──────┴──┐  ┌─────┴───┐  ┌───┴──────┐       │
│                   │ ctrl-01 │  │ ctrl-02  │  │ ctrl-03  │       │
│                   │  (AZ1)  │  │  (AZ2)   │  │  (AZ3)   │       │
│                   └────┬────┘  └────┬─────┘  └────┬─────┘       │
│                        │            │              │              │
│                   ┌────┴────────────┴──────────────┴────┐        │
│                   │     MariaDB Galera Cluster           │        │
│                   │     db-01 ←→ db-02 ←→ db-03         │        │
│                   └─────────────────────────────────────┘        │
│                   ┌─────────────────────────────────────┐        │
│                   │     RabbitMQ Quorum Queues           │        │
│                   │     mq-01 ←→ mq-02 ←→ mq-03         │        │
│                   └─────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

## Keystone (Identity Service)

### Função
Autenticação, autorização, catálogo de serviços e federation.

### Topologia
- 3 instâncias (uma por AZ) atrás de HAProxy
- Backend: MariaDB Galera (Fernet tokens, sem persistência de token)
- Cache: Memcached cluster (co-located nos controllers)

### HA Strategy
- Active-Active (stateless com Fernet tokens)
- Token rotation automática via cron (primary key rotation a cada 1h)
- Credential rotation a cada 24h

### Configuração Chave

```ini
[token]
provider = fernet
expiration = 3600

[cache]
enabled = true
backend = dogpile.cache.memcached
memcache_servers = ctrl-01:11211,ctrl-02:11211,ctrl-03:11211

[fernet_tokens]
key_repository = /etc/keystone/fernet-keys/
max_active_keys = 3
```

## Nova (Compute Service)

### API Layer
- 3 instâncias nova-api (uma por AZ)
- nova-scheduler: 3 instâncias com filtros customizados
- nova-conductor: 3 instâncias (proxy DB para computes)

### Cell Architecture

```
         ┌──────────────┐
         │   Cell0 DB   │ (apenas cell mappings)
         └──────┬───────┘
                │
         ┌──────┴───────┐
         │  nova-api    │
         │  (super)     │
         └──────┬───────┘
                │
    ┌───────────┼───────────┐
    │           │           │
┌───┴───┐  ┌───┴───┐  ┌───┴───┐
│Cell-1 │  │Cell-2 │  │Cell-3 │
│ (AZ1) │  │ (AZ2) │  │ (AZ3) │
│36 comp│  │36 comp│  │36 comp│
└───────┘  └───────┘  └───────┘
```

- **Cell0**: Metadata only (cell mappings, instance mappings para falhas)
- **Cell-1/2/3**: Uma cell por AZ, cada uma com seu próprio DB e MQ

### Scheduler Filters

```ini
[filter_scheduler]
available_filters = nova.scheduler.filters.all_filters
enabled_filters = AvailabilityZoneFilter,ComputeFilter,ComputeCapabilitiesFilter,ImagePropertiesFilter,ServerGroupAntiAffinityFilter,ServerGroupAffinityFilter,AggregateInstanceExtraSpecsFilter,NUMATopologyFilter
weight_classes = nova.scheduler.weights.all_weighers
```

## Neutron (Network Service)

### Topologia
- neutron-server: 3 instâncias (stateless, atrás de HAProxy)
- OVN Northbound DB: 3 nós (Raft consensus)
- OVN Southbound DB: 3 nós (Raft consensus)
- ovn-controller: em cada compute e network node

### OVN Architecture

```
┌────────────────────────────────────────────────┐
│              Neutron Server (ML2/OVN)           │
└──────────────────────┬─────────────────────────┘
                       │
┌──────────────────────┴─────────────────────────┐
│           OVN Northbound DB (Raft)              │
│     ctrl-01 (leader) ←→ ctrl-02 ←→ ctrl-03     │
└──────────────────────┬─────────────────────────┘
                       │
┌──────────────────────┴─────────────────────────┐
│           OVN Southbound DB (Raft)              │
│     ctrl-01 (leader) ←→ ctrl-02 ←→ ctrl-03     │
└──────────────────────┬─────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
    ┌────┴────┐  ┌─────┴────┐  ┌────┴────┐
    │ovn-ctrl │  │ ovn-ctrl  │  │ovn-ctrl │
    │(compute)│  │(net-node) │  │(compute)│
    └─────────┘  └──────────┘  └─────────┘
```

## MariaDB Galera Cluster

### Topologia
- 3 nós (um por AZ) com replicação síncrona
- Arbitrator (garbd) não necessário com 3 nós
- wsrep_cluster_size = 3

### Configuração

```ini
[mysqld]
binlog_format = ROW
default_storage_engine = InnoDB
innodb_autoinc_lock_mode = 2
innodb_buffer_pool_size = 128G
innodb_log_file_size = 2G
innodb_flush_log_at_trx_commit = 2
max_connections = 4096
wsrep_on = ON
wsrep_provider = /usr/lib/galera/libgalera_smm.so
wsrep_cluster_name = "openstack_galera"
wsrep_cluster_address = "gcomm://10.0.200.21,10.0.200.22,10.0.200.23"
wsrep_node_address = "10.0.200.21"
wsrep_sst_method = mariabackup
wsrep_sst_auth = "sst_user:SECURE_PASSWORD"
wsrep_slave_threads = 16
wsrep_provider_options = "gcache.size=2G; gcs.fc_limit=256"
```

### HA Behavior
- **Split-brain**: Nó isolado entra em non-primary (read-only)
- **SST**: Full state transfer via mariabackup (para nós que ficaram muito atrás)
- **IST**: Incremental state transfer (para gaps pequenos no gcache)
- **Monitoring**: `wsrep_cluster_status = Primary` e `wsrep_ready = ON`

## RabbitMQ Cluster

### Topologia
- 3 nós (um por AZ) com Quorum Queues
- Quorum queues usam Raft para replicação

### Configuração

```ini
# /etc/rabbitmq/rabbitmq.conf
cluster_formation.peer_discovery_backend = classic_config
cluster_formation.classic_config.nodes.1 = rabbit@mq-az1fd1-01
cluster_formation.classic_config.nodes.2 = rabbit@mq-az2fd1-01
cluster_formation.classic_config.nodes.3 = rabbit@mq-az3fd1-01

# Quorum queues como default
default_queue_type = quorum

# Limites de memória
vm_memory_high_watermark.relative = 0.6
vm_memory_high_watermark_paging_ratio = 0.8

# Networking
tcp_listen_options.backlog = 4096
tcp_listen_options.nodelay = true
tcp_listen_options.sndbuf = 196608
tcp_listen_options.recbuf = 196608

# Heartbeat
heartbeat = 60

# Management
management.listener.port = 15672
management.listener.ssl = false
```

### OpenStack Integration

```ini
# Em cada serviço OpenStack
[oslo_messaging_rabbit]
rabbit_hosts = mq-az1fd1-01:5672,mq-az2fd1-01:5672,mq-az3fd1-01:5672
rabbit_retry_interval = 1
rabbit_retry_backoff = 2
rabbit_max_retries = 0
rabbit_ha_queues = false  # Não necessário com quorum queues
rabbit_quorum_queue = true
heartbeat_timeout_threshold = 60
heartbeat_rate = 2
```

## HAProxy + Keepalived

### Keepalived (VRRP)

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│  lb-01   │     │  lb-02   │     │  lb-03   │
│  MASTER  │     │  BACKUP  │     │  BACKUP  │
│ pri=101  │     │ pri=100  │     │ pri=99   │
└────┬─────┘     └────┬─────┘     └────┬─────┘
     │                 │                 │
     └────────┬────────┴────────┬────────┘
              │                 │
         VIP: 10.0.10.5    VIP: 10.0.100.5
         (Public API)      (Internal API)
```

### HAProxy Backend Strategy

| Serviço | Balance | Health Check |
|---------|---------|--------------|
| Keystone | roundrobin | HTTP GET /healthcheck |
| Nova API | leastconn | HTTP GET / |
| Neutron | roundrobin | HTTP GET / |
| Glance | source | HTTP GET /healthcheck |
| Cinder | roundrobin | HTTP GET / |
| Horizon | source (sticky) | HTTP GET / |
| MariaDB | source | `option mysql-check user haproxy_check` — Requer usuário no MariaDB: `CREATE USER 'haproxy_check'@'%';` (sem senha, sem grants) |
| RabbitMQ | roundrobin | TCP check |

## Memcached

### Topologia
- 3 instâncias (co-located nos controllers)
- Consistent hashing para distribuição de keys
- Sem replicação (cache é efêmero)

### Configuração
```
-m 4096
-c 8192
-t 4
-l 10.0.100.11
```

## Placement API

### Função
Resource tracking e scheduling decisions para Nova.

### Topologia
- 3 instâncias (co-located nos controllers)
- Stateless, backend MariaDB
- Atrás de HAProxy

## Heat (Orchestration)

### Topologia
- heat-api: 3 instâncias
- heat-engine: 3 instâncias (distributed lock via DB)
- Convergence engine habilitado

## Horizon (Dashboard)

### Topologia
- 3 instâncias com session affinity (HAProxy source balancing)
- Django sessions em Memcached
- SSL termination no HAProxy

## Serviços Auxiliares

| Serviço | Instâncias | Localização | HA |
|---------|-----------|-------------|-----|
| Octavia API | 3 | Controllers | Active-Active |
| Octavia Worker | 3 | Controllers | Active-Active |
| Octavia HM | 3 | Controllers | Active-Passive |
| Barbican API | 3 | Controllers | Active-Active |
| Designate API | 3 | Controllers | Active-Active |
| Designate Central | 3 | Controllers | Active-Passive (tooz) |
| Designate Worker | 3 | Controllers | Active-Active |

## Fault Domain Awareness

| Componente | Failure Impact | Recovery |
|------------|---------------|----------|
| 1 Controller down | Sem impacto (2/3 healthy) | Auto-failover |
| 1 DB node down | Sem impacto (2/3 quorum) | Auto-rejoin |
| 1 MQ node down | Sem impacto (quorum queues) | Auto-rejoin |
| 1 AZ down | 33% capacity loss | Manual failover de VMs |
| Network partition | Split-brain protection | Galera non-primary |

## Decisões Arquiteturais

1. **Fernet Tokens**: Sem persistência de token no DB, reduz carga e elimina token flush
2. **Nova Cells**: Isolamento de falha por AZ, escalabilidade independente
3. **OVN Raft**: Consensus distribuído sem dependência externa (ZooKeeper)
4. **Quorum Queues**: Substituem mirrored queues com melhor performance e consistência
5. **HAProxy source para Glance**: Evita re-upload em caso de retry (uploads grandes)
6. **Galera wsrep_slave_threads=16**: Paralelismo de aplicação de writesets
7. **Memcached sem replicação**: Cache miss é aceitável, simplicidade operacional

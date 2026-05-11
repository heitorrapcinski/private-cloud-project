# 05 - Design do Storage Plane

## Visão Geral

```
┌─────────────────────────────────────────────────────────────────┐
│                      Storage Plane                                │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    Swift (Object Storage)                   │  │
│  │  18 nodes × 12 HDDs = 216 drives (3.456 PB raw)          │  │
│  │  Replication: 3 replicas across AZs                        │  │
│  │  Proxy: co-located on controllers                          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   Cinder (Block Storage)                    │  │
│  │  3 nodes × 24 NVMe = 72 drives (276 TB raw)              │  │
│  │  Backend: LVM over NVMe (iSCSI target)                    │  │
│  │  Replication: Cinder volume replication (async)            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   Glance (Image Service)                    │  │
│  │  Backend: Swift (default) + Cinder (for large images)     │  │
│  │  Cache: Local NVMe on controllers                          │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Swift (Object Storage)

### Ring Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Swift Rings                            │
│                                                          │
│  Account Ring    Container Ring    Object Ring           │
│  ┌──────────┐   ┌──────────┐     ┌──────────┐         │
│  │ part=14  │   │ part=14  │     │ part=14  │         │
│  │ repl=3   │   │ repl=3   │     │ repl=3   │         │
│  │ min_hr=1 │   │ min_hr=1 │     │ min_hr=1 │         │
│  └──────────┘   └──────────┘     └──────────┘         │
│                                                          │
│  Zones (mapped to AZs):                                 │
│    Zone 1 = AZ1 (swift-01..06)                          │
│    Zone 2 = AZ2 (swift-07..12)                          │
│    Zone 3 = AZ3 (swift-13..18)                          │
└─────────────────────────────────────────────────────────┘
```

### Ring Configuration

```bash
# Create rings (partition power=14, replicas=3, min_part_hours=1)
swift-ring-builder account.builder create 14 3 1
swift-ring-builder container.builder create 14 3 1
swift-ring-builder object.builder create 14 3 1

# Add devices - AZ1 (Zone 1)
for i in $(seq 1 6); do
  for disk in $(seq 1 12); do
    swift-ring-builder object.builder add \
      --region 1 --zone 1 \
      --ip 10.0.20.$((100+i)) --port 6200 \
      --device sd$(echo {b..m} | cut -d' ' -f$disk) \
      --weight 100
  done
done

# Add devices - AZ2 (Zone 2)
for i in $(seq 7 12); do
  for disk in $(seq 1 12); do
    swift-ring-builder object.builder add \
      --region 1 --zone 2 \
      --ip 10.0.21.$((100+i-6)) --port 6200 \
      --device sd$(echo {b..m} | cut -d' ' -f$disk) \
      --weight 100
  done
done

# Add devices - AZ3 (Zone 3)
for i in $(seq 13 18); do
  for disk in $(seq 1 12); do
    swift-ring-builder object.builder add \
      --region 1 --zone 3 \
      --ip 10.0.22.$((100+i-12)) --port 6200 \
      --device sd$(echo {b..m} | cut -d' ' -f$disk) \
      --weight 100
  done
done

# Rebalance
swift-ring-builder account.builder rebalance
swift-ring-builder container.builder rebalance
swift-ring-builder object.builder rebalance
```

### Swift Proxy Configuration

```ini
# /etc/swift/proxy-server.conf
[DEFAULT]
bind_ip = 0.0.0.0
bind_port = 8080
workers = 16
log_level = INFO

[pipeline:main]
pipeline = catch_errors gatekeeper healthcheck proxy-logging cache listing_formats bulk tempurl ratelimit crossdomain authtoken keystoneauth staticweb copy container-quotas account-quotas slo dlo versioned_writes symlink proxy-logging proxy-server

[filter:authtoken]
paste.filter_factory = keystonemiddleware.auth_token:filter_factory
www_authenticate_uri = http://10.0.10.5:5000
auth_url = http://10.0.100.5:5000
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = swift
password = SWIFT_PASS
delay_auth_decision = True
cache = swift.cache
memcache_security_strategy = ENCRYPT

[filter:cache]
use = egg:swift#memcache
memcache_servers = ctrl-01:11211,ctrl-02:11211,ctrl-03:11211

[app:proxy-server]
use = egg:swift#proxy
account_autocreate = true
node_timeout = 60
conn_timeout = 3.5
sorting_method = affinity
read_affinity = r1=100
write_affinity = r1
write_affinity_node_count = 2 * replicas
```

### Storage Policies

```ini
# /etc/swift/swift.conf
[swift-hash]
swift_hash_path_suffix = RANDOM_HASH_1
swift_hash_path_prefix = RANDOM_HASH_2

[storage-policy:0]
name = standard
default = yes
policy_type = replication

[storage-policy:1]
name = erasure-coding
policy_type = erasure_coding
ec_type = liberasurecode_rs_vand
ec_num_data_fragments = 10
ec_num_parity_fragments = 4
ec_object_segment_size = 1048576
```

### Capacidade

| Métrica | Valor |
|---------|-------|
| Raw capacity | 3.456 PB (18 × 12 × 16TB) |
| Usable (3 replicas) | 1.152 PB |
| Usable (EC 10+4) | 2.469 PB |
| IOPS (HDD) | ~2,160 random (216 × 10 IOPS) |
| Throughput | ~43 GB/s sequential (216 × 200 MB/s) |

## Cinder (Block Storage)

### Backend Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Cinder Architecture                      │
│                                                          │
│  cinder-api (3x) → cinder-scheduler → cinder-volume    │
│                                                          │
│  Backend: LVM over NVMe                                  │
│  Protocol: iSCSI (tgtd) / NVMe-oF (future)             │
│                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ cinder-az1  │  │ cinder-az2  │  │ cinder-az3  │    │
│  │ 24x NVMe    │  │ 24x NVMe    │  │ 24x NVMe    │    │
│  │ VG: cinder  │  │ VG: cinder  │  │ VG: cinder  │    │
│  │ 92 TB usable│  │ 92 TB usable│  │ 92 TB usable│    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### Cinder Configuration

```ini
# /etc/cinder/cinder.conf
[DEFAULT]
enabled_backends = lvm-az1,lvm-az2,lvm-az3
default_volume_type = standard-nvme
scheduler_driver = cinder.scheduler.filter_scheduler.FilterScheduler
backup_driver = cinder.backup.drivers.swift.SwiftBackupDriver

[lvm-az1]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
target_protocol = iscsi
target_helper = tgtadm
volume_backend_name = LVM_NVMe_AZ1
target_ip_address = 10.0.20.201

[lvm-az2]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
target_protocol = iscsi
target_helper = tgtadm
volume_backend_name = LVM_NVMe_AZ2
target_ip_address = 10.0.21.201

[lvm-az3]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
target_protocol = iscsi
target_helper = tgtadm
volume_backend_name = LVM_NVMe_AZ3
target_ip_address = 10.0.22.201

[backend_defaults]
use_multipath_for_image_xfer = true
enforce_multipath_for_image_xfer = true
```

### Volume Types

```bash
openstack volume type create standard-nvme \
  --property volume_backend_name=LVM_NVMe_AZ1

openstack volume type create high-iops \
  --property volume_backend_name=LVM_NVMe_AZ1 \
  --property provisioning:type=thin

openstack volume type create replicated \
  --property replication_enabled='<is> True'
```

### Cinder Backup

```ini
[DEFAULT]
backup_driver = cinder.backup.drivers.swift.SwiftBackupDriver
backup_swift_url = http://10.0.10.5:8080/v1
backup_swift_container = cinder-backups
backup_swift_object_size = 52428800
backup_swift_retry_attempts = 3
```

### Capacidade

| Métrica | Valor |
|---------|-------|
| Raw capacity | 276 TB (3 × 24 × 3.84TB) |
| Usable (thin provisioning 2:1) | ~552 TB logical |
| IOPS per node | ~2.4M random 4K (24 × 100K) |
| Latency | < 200μs (NVMe) |
| Throughput per node | ~84 GB/s (24 × 3.5 GB/s) |

## Glance (Image Service)

### Backend Configuration

```ini
# /etc/glance/glance-api.conf
[DEFAULT]
show_image_direct_url = true
enabled_backends = swift:swift,cinder:cinder

[glance_store]
default_backend = swift

[swift]
swift_store_auth_address = http://10.0.100.5:5000/v3
swift_store_user = service:glance
swift_store_key = GLANCE_PASS
swift_store_container = glance-images
swift_store_create_container_on_put = true
swift_store_large_object_size = 5120
swift_store_large_object_chunk_size = 200
swift_store_multi_tenant = false
swift_store_endpoint_type = internalURL

[cinder]
cinder_store_auth_address = http://10.0.100.5:5000/v3
cinder_store_user_name = glance
cinder_store_password = GLANCE_PASS
cinder_store_project_name = service
cinder_catalog_info = volumev3::internalURL

[image_cache]
image_cache_dir = /var/lib/glance/image-cache
image_cache_max_size = 107374182400  # 100GB NVMe cache
```

### Image Caching Strategy

```
┌──────────────────────────────────────────────────┐
│              Glance Image Flow                     │
│                                                    │
│  Upload → Swift (persistent, 3 replicas)          │
│                                                    │
│  Download → Check local NVMe cache                │
│           → Cache miss: fetch from Swift          │
│           → Cache hit: serve from NVMe            │
│                                                    │
│  Nova boot → glance_api_servers (HAProxy)         │
│           → Image streamed to compute             │
│           → Copy-on-write (qcow2 backing file)   │
└──────────────────────────────────────────────────┘
```

### Image Properties Standards

```bash
# Base images com metadata
openstack image set ubuntu-24.04 \
  --property os_distro=ubuntu \
  --property os_version=24.04 \
  --property hw_disk_bus=virtio \
  --property hw_vif_model=virtio \
  --property hw_qemu_guest_agent=yes \
  --property hw_scsi_model=virtio-scsi \
  --property os_require_quiesce=yes
```

## Storage Network Design

### iSCSI Multipath

```
┌──────────────┐          ┌──────────────┐
│   Compute    │          │   Cinder     │
│              │          │              │
│  bond0.20 ───┼──path1──┼── bond0.20   │
│  (10.0.20.x) │          │ (10.0.20.201)│
│              │          │              │
│  bond1.20 ───┼──path2──┼── bond1.20   │
│  (10.0.20.x) │          │ (10.0.20.201)│
└──────────────┘          └──────────────┘
```

### Multipath Configuration

```ini
# /etc/multipath.conf
defaults {
    user_friendly_names yes
    find_multipaths yes
    path_grouping_policy failover
    path_selector "round-robin 0"
    failback immediate
    no_path_retry 12
}

blacklist {
    devnode "^(ram|raw|loop|fd|md|dm-|sr|scd|st)[0-9]*"
}
```

## Data Protection

### Swift
- 3 replicas across AZs (zone-aware placement)
- Auditor daemon verifica integridade continuamente
- Replicator daemon repara automaticamente

### Cinder
- Snapshots (copy-on-write, instantâneo)
- Backup to Swift (full + incremental)
- Volume replication (async, cross-AZ)

### Glance
- Images stored in Swift (inherits 3x replication)
- Image cache é efêmero (rebuild automático)

## Decisões Arquiteturais

1. **Swift com HDD**: Custo/TB otimizado, replicação 3x compensa performance individual
2. **Cinder com NVMe/LVM**: Simplicidade operacional, performance extrema, sem dependência externa
3. **iSCSI (não NVMe-oF)**: Maturidade, compatibilidade, multipath bem suportado
4. **Glance em Swift**: Replicação automática, sem SPOF, imagens grandes suportadas
5. **EC policy para cold data**: 10+4 oferece 71% de eficiência vs 33% com 3 replicas
6. **Partition power 14**: 2^14 = 16384 partitions, suporta até ~600 drives sem rebalance
7. **Thin provisioning 2:1**: Maximiza utilização sem over-commit excessivo

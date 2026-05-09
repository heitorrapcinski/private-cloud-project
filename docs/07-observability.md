# 07 - Design de Observabilidade

## Visão Geral

```
┌─────────────────────────────────────────────────────────────────┐
│                   Observability Stack                             │
│                                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │  Metrics    │  │   Logs      │  │   Alerts    │            │
│  │             │  │             │  │             │            │
│  │ Ceilometer  │  │ Fluentd/    │  │    Aodh     │            │
│  │ Gnocchi     │  │ Loki        │  │ Prometheus  │            │
│  │ Prometheus  │  │             │  │ AlertMgr    │            │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │
│         │                 │                 │                    │
│         └─────────────────┼─────────────────┘                   │
│                           │                                      │
│                    ┌──────┴──────┐                               │
│                    │   Grafana   │                               │
│                    │ Dashboards  │                               │
│                    └─────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
```

## Ceilometer (Metering)

### Função
Coleta de métricas de uso de recursos OpenStack para billing e capacity planning.

### Arquitetura

```
┌──────────────────────────────────────────────────┐
│            Ceilometer Pipeline                    │
│                                                    │
│  Notification Agent (3x)                          │
│  ├── Listens: oslo.messaging notifications       │
│  ├── Transforms: pipeline.yaml                    │
│  └── Publishes: → Gnocchi                        │
│                                                    │
│  Polling Agent (per compute)                      │
│  ├── Polls: libvirt, SNMP, IPMI                  │
│  ├── Interval: 300s (configurable)               │
│  └── Publishes: → Gnocchi                        │
└──────────────────────────────────────────────────┘
```

### Configuração

```ini
# /etc/ceilometer/ceilometer.conf
[DEFAULT]
transport_url = rabbit://openstack:PASS@mq-01:5672,mq-02:5672,mq-03:5672/

[notification]
workers = 4
messaging_urls = rabbit://openstack:PASS@mq-01:5672,mq-02:5672,mq-03:5672/

[publisher_gnocchi]
filter_service_activity = false
archive_policy = ceilometer-low-rate
request_timeout = 60

[polling]
cfg_file = /etc/ceilometer/polling.yaml
```

### Polling Configuration

```yaml
# /etc/ceilometer/polling.yaml
---
sources:
  - name: cpu_source
    interval: 60
    meters:
      - cpu
      - cpu_util
    resources:

  - name: disk_source
    interval: 300
    meters:
      - disk.read.bytes
      - disk.write.bytes
      - disk.read.requests
      - disk.write.requests
    resources:

  - name: network_source
    interval: 300
    meters:
      - network.incoming.bytes
      - network.outgoing.bytes
      - network.incoming.packets
      - network.outgoing.packets
    resources:

  - name: instance_source
    interval: 600
    meters:
      - memory.usage
      - vcpus
      - memory
    resources:
```

## Gnocchi (Time-Series Database)

### Arquitetura

```
┌──────────────────────────────────────────────────┐
│              Gnocchi Architecture                  │
│                                                    │
│  gnocchi-api (3x, behind HAProxy)                │
│  gnocchi-metricd (3x, workers)                   │
│                                                    │
│  Storage:                                         │
│  ├── Index: MariaDB (shared with OpenStack)      │
│  ├── Measures: Swift (object storage)            │
│  └── Aggregates: Swift (pre-computed)            │
└──────────────────────────────────────────────────┘
```

### Configuração

```ini
# /etc/gnocchi/gnocchi.conf
[DEFAULT]
log_dir = /var/log/gnocchi

[api]
auth_mode = keystone
max_limit = 1000

[indexer]
url = mysql+pymysql://gnocchi:PASS@10.0.200.5/gnocchi

[storage]
driver = swift
swift_auth_version = 3
swift_authurl = http://10.0.100.5:5000/v3
swift_user = service:gnocchi
swift_key = GNOCCHI_PASS
swift_project_name = service
swift_container_prefix = gnocchi

[metricd]
workers = 8
metric_processing_delay = 30
metric_cleanup_delay = 300
```

### Archive Policies

```yaml
# Políticas de retenção
archive_policies:
  - name: ceilometer-low-rate
    aggregation_methods: [mean, min, max, count]
    definition:
      - granularity: 5m
        timespan: 30 days
      - granularity: 1h
        timespan: 365 days
      - granularity: 1d
        timespan: 10 years

  - name: ceilometer-high-rate
    aggregation_methods: [mean, min, max, count, sum]
    definition:
      - granularity: 1m
        timespan: 7 days
      - granularity: 5m
        timespan: 30 days
      - granularity: 1h
        timespan: 365 days

  - name: infrastructure
    aggregation_methods: [mean, min, max, std]
    definition:
      - granularity: 10s
        timespan: 1 day
      - granularity: 1m
        timespan: 7 days
      - granularity: 5m
        timespan: 90 days
```

## Aodh (Alarming)

### Função
Alarmes baseados em métricas do Gnocchi e eventos do Ceilometer.

### Configuração

```ini
# /etc/aodh/aodh.conf
[DEFAULT]
transport_url = rabbit://openstack:PASS@mq-01:5672,mq-02:5672,mq-03:5672/
evaluation_interval = 60

[database]
connection = mysql+pymysql://aodh:PASS@10.0.200.5/aodh

[evaluator]
workers = 4

[notifier]
workers = 4
```

### Alarm Examples

```bash
# CPU alarm for autoscaling
openstack alarm create \
  --name cpu-high \
  --type gnocchi_resources_threshold \
  --metric cpu_util \
  --threshold 80 \
  --comparison-operator gt \
  --aggregation-method mean \
  --granularity 300 \
  --evaluation-periods 3 \
  --resource-type instance \
  --query '{"=": {"server_group": "web-tier"}}' \
  --alarm-action 'http://heat-api:8004/v1/signal/scale-up' \
  --ok-action 'http://heat-api:8004/v1/signal/scale-down'

# Disk usage alarm
openstack alarm create \
  --name disk-critical \
  --type gnocchi_resources_threshold \
  --metric disk.usage \
  --threshold 90 \
  --comparison-operator gt \
  --aggregation-method max \
  --granularity 300 \
  --evaluation-periods 2 \
  --alarm-action 'http://webhook.ops.internal/disk-alert'
```

## Prometheus + Grafana (Infrastructure Monitoring)

### Prometheus Architecture

```
┌──────────────────────────────────────────────────┐
│           Prometheus Stack                         │
│                                                    │
│  Prometheus Server (2x, HA with Thanos)          │
│  ├── Scrape: node_exporter (all hosts)           │
│  ├── Scrape: haproxy_exporter                    │
│  ├── Scrape: mysqld_exporter                     │
│  ├── Scrape: rabbitmq_exporter                   │
│  ├── Scrape: openstack_exporter                  │
│  ├── Scrape: libvirt_exporter                    │
│  └── Scrape: blackbox_exporter                   │
│                                                    │
│  AlertManager (3x, clustered)                    │
│  ├── Route: PagerDuty (P1/P2)                   │
│  ├── Route: Slack (#ops-alerts)                  │
│  └── Route: Email (P3/P4)                        │
│                                                    │
│  Grafana (2x, behind HAProxy)                    │
│  ├── Datasource: Prometheus                      │
│  ├── Datasource: Gnocchi                         │
│  └── Datasource: Loki                            │
└──────────────────────────────────────────────────┘
```

### Prometheus Scrape Config

```yaml
# /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - /etc/prometheus/rules/*.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager-01:9093','alertmanager-02:9093','alertmanager-03:9093']

scrape_configs:
  - job_name: 'node'
    file_sd_configs:
      - files: ['/etc/prometheus/targets/nodes.yml']
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance

  - job_name: 'haproxy'
    static_configs:
      - targets: ['lb-01:9101','lb-02:9101','lb-03:9101']

  - job_name: 'mysql'
    static_configs:
      - targets: ['db-01:9104','db-02:9104','db-03:9104']

  - job_name: 'rabbitmq'
    static_configs:
      - targets: ['mq-01:15692','mq-02:15692','mq-03:15692']

  - job_name: 'openstack'
    scrape_interval: 60s
    static_configs:
      - targets: ['ctrl-01:9180']
```

### Alert Rules

```yaml
# /etc/prometheus/rules/openstack.yml
groups:
  - name: openstack_control_plane
    rules:
      - alert: GaleraClusterSizeDown
        expr: mysql_global_status_wsrep_cluster_size < 3
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Galera cluster degraded ({{ $value }} nodes)"

      - alert: RabbitMQQueueBacklog
        expr: rabbitmq_queue_messages > 10000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "RabbitMQ queue {{ $labels.queue }} has {{ $value }} messages"

      - alert: NovaComputeDown
        expr: openstack_nova_service_state{binary="nova-compute"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Nova compute {{ $labels.host }} is down"

      - alert: CinderVolumeSpaceLow
        expr: (cinder_pool_capacity_free_gb / cinder_pool_capacity_total_gb) < 0.15
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Cinder pool {{ $labels.pool }} has less than 15% free space"

      - alert: HighAPILatency
        expr: histogram_quantile(0.99, rate(haproxy_backend_http_response_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "API {{ $labels.backend }} p99 latency > 2s"
```

## Log Aggregation

### Stack

```
Hosts → Fluentd (DaemonSet) → Loki → Grafana
```

### Fluentd Configuration

```xml
<!-- /etc/fluentd/conf.d/openstack.conf -->
<source>
  @type tail
  path /var/log/nova/*.log,/var/log/neutron/*.log,/var/log/keystone/*.log
  pos_file /var/log/fluentd/openstack.pos
  tag openstack.*
  <parse>
    @type regexp
    expression /^(?<time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}.\d{3}) (?<pid>\d+) (?<level>\w+) (?<module>[\w.]+) \[(?<request_id>[^\]]*)\] (?<message>.*)$/
  </parse>
</source>

<match openstack.**>
  @type loki
  url http://loki.cloud.internal:3100
  <label>
    service $.tag
    level $.level
    host "#{Socket.gethostname}"
  </label>
  <buffer>
    @type file
    path /var/log/fluentd/buffer/loki
    flush_interval 5s
    chunk_limit_size 1m
  </buffer>
</match>
```

## Dashboards

### Grafana Dashboard Structure

| Dashboard | Métricas |
|-----------|----------|
| Cloud Overview | Total VMs, vCPUs used, RAM used, storage used |
| Control Plane Health | API latency, DB replication lag, MQ queue depth |
| Compute Capacity | Per-AZ utilization, overcommit ratios |
| Storage Performance | IOPS, throughput, latency per backend |
| Network | Bandwidth per VLAN, packet drops, OVN flows |
| Tenant Usage | Per-project resource consumption |
| Alerts | Active alerts, alert history, SLA metrics |

## SLA Metrics

| Métrica | Target | Medição |
|---------|--------|---------|
| API Availability | 99.99% | Blackbox prober (5s interval) |
| VM Availability | 99.95% | Nova instance state monitoring |
| Storage Availability | 99.99% | Swift/Cinder health checks |
| API Latency (p99) | < 1s | HAProxy metrics |
| VM Boot Time | < 30s | End-to-end probe |
| Volume Attach | < 10s | End-to-end probe |

## Decisões Arquiteturais

1. **Ceilometer + Gnocchi**: Nativo OpenStack, billing-ready, archive policies flexíveis
2. **Prometheus para infra**: Melhor para alerting, pull-based, HA com Thanos
3. **Loki para logs**: Lightweight, label-based, integra com Grafana
4. **Aodh para autoscaling**: Integração nativa com Heat, threshold-based
5. **Dual monitoring**: Ceilometer para tenant metering, Prometheus para ops
6. **Swift como backend Gnocchi**: Reusa infraestrutura existente, durável
7. **AlertManager clustered**: Deduplicação, silencing, routing por severidade

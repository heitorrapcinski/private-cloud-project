---
name: openstack-ops
description: >
  Operate, monitor, troubleshoot, and optimize a running OpenStack cloud.
  Use this skill for operational tasks: diagnosing failures, checking HA status,
  reading logs, benchmarking performance, managing quotas, setting up
  monitoring with Prometheus/Grafana, configuring centralized logging with
  OpenSearch, using Rally for load testing, using Watcher for resource
  optimization, using OSProfiler for tracing, managing Masakari for instance
  HA, or working with Ceilometer/Gnocchi/Aodh for telemetry and alerting.
  Triggers on: "my nova-compute is down", "how to check RabbitMQ health",
  "show me the HA status of my control plane", "benchmark my cloud with Rally",
  "set up Prometheus for OpenStack", "configure Aodh to alert on CPU alarm",
  "trace a slow API call with OSProfiler", "how does Masakari detect
  hypervisor failures", "optimize VM placement with Watcher", "query Gnocchi
  for instance metrics", "check Ceilometer pipeline config", "drain a compute
  node for maintenance". Always look at the source code and runbooks first.
---

# OpenStack Operations Guide

Service source code is at GitHub (mirror of OpenDev, branch `stable/2026.1`):
```bash
git clone https://github.com/openstack/<service> --branch stable/2026.1
# Examples relevant here: masakari, watcher, ceilometer, aodh, osprofiler, rally
```
All path references below are relative to each service repo root.

## Service health checks

### Quick status (Kolla-Ansible managed cluster)
```bash
# All containers on all hosts
ansible -i multinode all -m shell -a "docker ps --format '{{.Names}}\t{{.Status}}'"

# Specific service logs
docker logs nova_compute --tail 100
docker logs neutron_l3_agent --tail 100

# OpenStack service list
openstack compute service list
openstack network agent list
openstack volume service list
```

### Nova
```bash
openstack compute service list          # all nova services + state
openstack hypervisor list               # compute nodes + resource totals
openstack hypervisor show <hostname>    # per-node resources
nova-manage cell_v2 list_cells         # cell structure
nova-manage cell_v2 discover_hosts     # force host discovery
```

### Neutron
```bash
openstack network agent list            # all agents + alive status
neutron-debug probe-create <network>   # create a probe port for testing
openstack router show <id>              # HA router state per agent
```

### Cinder
```bash
openstack volume service list           # scheduler + volume services
cinder get-pools --detail               # backend pools + capacity
```

### RabbitMQ
```bash
docker exec rabbitmq rabbitmqctl cluster_status
docker exec rabbitmq rabbitmqctl list_queues name messages consumers
docker exec rabbitmq rabbitmqctl list_connections
```

### Valkey (replaces Redis in 2026.1)
```bash
# Valkey is the in-memory store for rate-limiting, caching, and OSProfiler
docker exec valkey valkey-cli ping          # should return PONG
docker exec valkey valkey-cli info server   # version and uptime
docker exec valkey valkey-cli info memory   # used_memory, maxmemory
docker exec valkey valkey-cli dbsize        # number of keys
```
> In Kolla-Ansible 2026.1, `enable_redis` is removed. Use `enable_valkey: "yes"`. Data is migrated automatically from Redis during upgrade.

### MariaDB / Galera
```bash
docker exec mariadb mysql -u root -p$(< /etc/kolla/passwords.yml grep database_password | awk '{print $2}') \
  -e "SHOW STATUS LIKE 'wsrep_%';"
# wsrep_cluster_size should equal number of DB nodes
# wsrep_local_state_comment should be 'Synced'
```

## High Availability (HA)

### HAProxy + Keepalived
```
ansible-collection-kolla\roles\haproxy\templates\haproxy.cfg.j2   ← HAProxy config template
ansible-collection-kolla\roles\keepalived\templates\keepalived.conf.j2
```

Check VIP ownership:
```bash
ip addr show | grep <kolla_internal_vip_address>
```

HAProxy stats page: `http://<VIP>:1984` (user/pass in `passwords.yml`)

### Nova instance HA (Masakari)
```
masakari\masakari\engine\manager.py        ← failover segment logic
masakari\masakari\compute\nova.py          ← nova RPC calls for evacuation
```

```bash
openstack segment list                     # failover segments
openstack segment host list <segment>      # hosts in segment
openstack notification list               # recent failure notifications
```

Masakari workflow:
1. `masakari-monitors` detects hypervisor/instance/process failure
2. Sends notification to `masakari-api`
3. `masakari-engine` runs evacuation taskflow
4. Calls `nova evacuate` on affected instances

### Neutron router HA (VRRP)
```
neutron\neutron\db\l3_hamode_db.py          ← HA router DB
neutron\neutron\agent\l3\ha_router.py       ← keepalived management
```
```bash
openstack router show <id> | grep ha       # ha=True means HA router
ip netns exec qrouter-<id> ip addr         # VIP inside router namespace
```

## Monitoring

### Prometheus + Grafana (Kolla-Ansible)

Enable in globals.yml:
```yaml
enable_prometheus: "yes"
enable_grafana: "yes"
```

Exporters deployed by Kolla:
- `node_exporter` — host metrics (CPU, RAM, disk, network)
- `libvirt_exporter` — per-instance metrics
- `ceph_exporter` — Ceph cluster metrics (if using Ceph)
- `haproxy_exporter` — HAProxy backend status
- `mysqld_exporter` — MariaDB metrics
- `rabbitmq_exporter` — RabbitMQ queue depths

Prometheus config is at: `ansible-collection-kolla\roles\prometheus\templates\`

Key queries:
```promql
# Nova compute instances running
libvirt_domain_info_virtual_cpus{state="running"}

# RabbitMQ queue depth
rabbitmq_queue_messages{queue="compute"}

# MySQL connections
mysql_global_status_threads_connected
```

### Telemetry: Ceilometer + Gnocchi + Aodh

```
ceilometer\ceilometer\pipeline\           ← pipeline and polling config
ceilometer\ceilometer\polling\            ← pollsters (per resource type)
gnocchi (separate repo)\gnocchi\rest\     ← Gnocchi API
aodh\aodh\evaluator\                      ← alarm evaluators
```

```bash
# Query Gnocchi for a metric
gnocchi metric list --resource-type instance
gnocchi measures show <metric-id> --start $(date -d '1 hour ago' --iso-8601=seconds)

# Create an Aodh threshold alarm
openstack alarm create \
  --type gnocchi_resources_threshold \
  --name cpu-high \
  --metric cpu_util \
  --threshold 80 \
  --comparison-operator gt \
  --resource-type instance \
  --resource-id <instance-id> \
  --alarm-action 'http://webhook-endpoint/'
```

Ceilometer pipeline config (`pipeline.yaml`) controls which meters are collected and at what interval. The `pollsters` section lists resource types; the `sinks` route data to Gnocchi.

## Centralized Logging (OpenSearch)

Enable in globals.yml:
```yaml
enable_opensearch: "yes"
enable_opensearch_dashboards: "yes"
```

Kolla deploys Fluentd on each node to ship Docker container logs → OpenSearch.

```
ansible-collection-kolla\roles\opensearch\    ← OpenSearch role
ansible-collection-kolla\roles\fluentd\       ← log shipping config
```

Log index pattern: `flog-YYYY.MM.DD`

Useful OpenSearch queries:
```json
{"query": {"bool": {"must": [
  {"match": {"Hostname": "compute01"}},
  {"match": {"programname": "nova-compute"}},
  {"range": {"@timestamp": {"gte": "now-1h"}}}
]}}}
```

## Benchmarking

### Rally
```bash
git clone https://github.com/openstack/rally-openstack --branch stable/2026.1
```

```bash
# Install
pip install rally-openstack

# Create deployment from existing cloud
rally deployment create --fromenv --name mycloud

# Run a scenario
rally task start --task task.yaml

# Show results
rally task results
rally task report --out report.html
```

Sample `task.yaml` (boot and delete servers):
```yaml
---
- title: Boot and delete servers
  workloads:
  - scenario:
      NovaServers.boot_and_delete_server:
        image: {name: cirros}
        flavor: {name: m1.tiny}
    runner:
      type: constant
      times: 10
      concurrency: 2
    contexts:
      users:
        tenants: 1
        users_per_tenant: 1
```

### OSProfiler (API call tracing)

OSProfiler traces a single API request across all OpenStack services.

Enable in each service's config:
```ini
[profiler]
enabled = true
hmac_keys = SECRET_KEY
connection_string = redis://localhost:6379
```

```bash
# Trigger a traced request
OS_PROFILE=SECRET_KEY openstack server create --name test --flavor m1.tiny --image cirros test

# Retrieve trace (returns trace_id)
osprofiler trace show <trace_id> --html > trace.html
```

OSProfiler source: `osprofiler\osprofiler\`

### Watcher (Resource Optimization)

```
watcher\watcher\decision_engine\strategy\strategies\   ← built-in strategies
  server_consolidation.py    ← consolidate VMs onto fewer hosts
  workload_stabilization.py  ← balance load across hosts
  zone_migration.py          ← migrate VMs between AZs
```

```bash
# Create an audit
openstack optimize audit create \
  --audit-template mytemplate \
  --goal SERVER_CONSOLIDATION \
  --strategy server_consolidation

# List recommendations
openstack optimize action plan list
openstack optimize action plan show <id>

# Execute
openstack optimize action plan start <id>
```

## Compute node maintenance

```bash
# 1. Disable compute (stop new scheduling)
openstack compute service set --disable --disable-reason "maintenance" <host> nova-compute

# 2. Live-migrate all instances off the node
for vm in $(openstack server list --host <host> -f value -c ID); do
  openstack server migrate --live-migration $vm
done

# 3. Verify node is empty
openstack server list --host <host>

# 4. Re-enable
openstack compute service set --enable <host> nova-compute
```

**Graceful shutdown (Gazpacho 2026.1+):** Nova services now support SIGTERM-based graceful shutdown. In-flight operations (live migration, resize, revert, external events) complete before the process exits. Configured via:
```ini
[DEFAULT]
graceful_shutdown_timeout = 180   # seconds to wait for in-flight ops
manager_shutdown_timeout  = 160   # must be < graceful_shutdown_timeout
```
To drain a compute node gracefully before maintenance, disable it first (step 1), wait for in-flight operations to complete, then send SIGTERM to `nova-compute`.

## Quota management

```bash
openstack quota show <project>
openstack quota set --instances 50 --cores 200 --ram 204800 <project>
openstack quota show --default   # view default quotas
```

Quota source:
```
nova\nova\quota.py          ← nova quota engine
nova\nova\conf\quota.py     ← config options (quota_instances, quota_cores…)
neutron\neutron\quota\      ← neutron quota engine
```

## Response format

For every operational question:

1. **Immediate diagnostic commands**: what to run right now to assess the situation.
2. **Source of truth in code**: which file/class governs this behavior.
3. **Common root causes**: ordered by likelihood, each with a distinguishing symptom.
4. **Remediation steps**: exact commands, not generic advice.
5. **Prevention**: config options or design choices that avoid recurrence.

Check if a project runbook exists for the scenario before diving into diagnostics.

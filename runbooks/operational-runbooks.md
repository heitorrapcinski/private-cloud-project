# Runbook: Galera Cluster Recovery

## Scenario: Single Node Failure

### Symptoms
- `wsrep_cluster_size` = 2
- Alert: `GaleraClusterSizeDown`

### Steps
```bash
# 1. Check cluster status on healthy nodes
mysql -e "SHOW STATUS LIKE 'wsrep_cluster%';"

# 2. Check failed node
ssh db-XX "systemctl status mariadb"

# 3. Restart MariaDB on failed node
ssh db-XX "systemctl restart mariadb"

# 4. Verify rejoin (IST should happen automatically)
mysql -e "SHOW STATUS LIKE 'wsrep_local_state_comment';"
# Expected: "Synced"

# 5. If IST fails (node too far behind), SST will trigger automatically
# Monitor: tail -f /var/log/mysql/error.log
```

### Escalation
If node cannot rejoin after 10 minutes, perform manual SST:
```bash
ssh db-XX "systemctl stop mariadb"
ssh db-XX "rm -rf /var/lib/mysql/*"
ssh db-XX "systemctl start mariadb"
# SST will rebuild from donor
```

---

## Scenario: Full Cluster Down (All 3 Nodes)

### Steps
```bash
# 1. Find the most advanced node
for node in db-01 db-02 db-03; do
  ssh $node "cat /var/lib/mysql/grastate.dat"
done
# Look for: seqno (highest = most recent)

# 2. Bootstrap from most advanced node
ssh db-XX "galera_new_cluster"

# 3. Start remaining nodes
ssh db-YY "systemctl start mariadb"
ssh db-ZZ "systemctl start mariadb"

# 4. Verify
mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
# Expected: 3
```

---

# Runbook: RabbitMQ Cluster Recovery

## Scenario: Single Node Failure

```bash
# 1. Check cluster status
rabbitmqctl cluster_status

# 2. Restart failed node
ssh mq-XX "systemctl restart rabbitmq-server"

# 3. Verify
rabbitmqctl cluster_status
# All 3 nodes should be listed as running
```

## Scenario: Network Partition

```bash
# 1. Identify partitioned node
rabbitmqctl cluster_status | grep partitions

# 2. Stop the minority partition node
ssh mq-XX "rabbitmqctl stop_app"
ssh mq-XX "rabbitmqctl reset"
ssh mq-XX "rabbitmqctl join_cluster rabbit@mq-az1fd1-01"
ssh mq-XX "rabbitmqctl start_app"
```

---

# Runbook: Compute Node Failure

## Scenario: Hypervisor Unresponsive

```bash
# 1. Verify node is truly down
ping compute-XX
ssh compute-XX "uptime" # timeout expected

# 2. Fence the node (if IPMI available)
ipmitool -I lanplus -H 172.16.0.XX -U admin -P PASS power cycle

# 3. Evacuate VMs to other hosts
openstack compute service set --disable compute-XX nova-compute
nova host-evacuate compute-XX

# 4. After node recovers
openstack compute service set --enable compute-XX nova-compute
```

---

# Runbook: OVN Database Recovery

## Scenario: OVN NB/SB Leader Election Failure

```bash
# 1. Check cluster status
ovs-appctl -t /var/run/ovn/ovnnb_db.ctl cluster/status OVN_Northbound

# 2. If a node is disconnected
ssh ctrl-XX "systemctl restart ovn-central"

# 3. Verify leader election
ovs-appctl -t /var/run/ovn/ovnnb_db.ctl cluster/status OVN_Northbound | grep -i leader
```

---

# Runbook: Swift Ring Rebalance (Adding Storage)

```bash
# 1. Add new devices to ring
swift-ring-builder object.builder add --region 1 --zone X --ip NEW_IP --port 6200 --device sdX --weight 100

# 2. Rebalance (moves minimum partitions)
swift-ring-builder object.builder rebalance

# 3. Distribute rings to all nodes
for node in $(cat /etc/swift/nodes.list); do
  scp /etc/swift/*.ring.gz ${node}:/etc/swift/
done

# 4. Verify
swift-ring-builder object.builder
swift-recon --replication
```

---

# Runbook: Certificate Rotation

```bash
# 1. Generate new certificates
./scripts/generate-certs.sh

# 2. Deploy to HAProxy
ansible-playbook -i inventory/multinode playbooks/rotate-certs.yml --tags haproxy

# 3. Reload HAProxy (zero-downtime)
ssh lb-01 "systemctl reload haproxy"
ssh lb-02 "systemctl reload haproxy"
ssh lb-03 "systemctl reload haproxy"

# 4. Verify
curl -v https://api.cloud.internal:5000/v3 2>&1 | grep "expire date"
```

---

# Runbook: Rolling OS Patching

```bash
# For each compute node:
# 1. Disable scheduling
openstack compute service set --disable --disable-reason "patching" ${HOST} nova-compute

# 2. Live migrate all VMs
nova host-evacuate-live ${HOST}

# 3. Wait for migrations to complete
watch "openstack server list --host ${HOST} --all-projects"

# 4. Patch
ssh ${HOST} "apt update && apt upgrade -y && reboot"

# 5. Wait for node to come back
until ssh ${HOST} "uptime"; do sleep 10; done

# 6. Re-enable
openstack compute service set --enable ${HOST} nova-compute

# 7. Verify
openstack hypervisor show ${HOST}
```

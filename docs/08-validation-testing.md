# 08 - Validação, Testes HA/DR e Troubleshooting

## Procedimentos de Validação Pós-Deploy

### Checklist Day 1

```bash
# 1. Serviços OpenStack
openstack service list
openstack endpoint list
openstack compute service list
openstack network agent list
openstack volume service list

# 2. Verificar HA
mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';"  # Expected: 3
rabbitmqctl cluster_status                          # 3 nodes running
ip addr show | grep 10.0.10.5                       # VIP active

# 3. Criar recursos de teste
openstack network create test-net
openstack subnet create test-subnet --network test-net --subnet-range 192.168.99.0/24
openstack router create test-router
openstack router set test-router --external-gateway external
openstack router add subnet test-router test-subnet
openstack server create --flavor m1.small --image ubuntu-24.04 --network test-net test-vm
openstack floating ip create external
openstack server add floating ip test-vm <FLOATING_IP>

# 4. Verificar conectividade
ping <FLOATING_IP>
ssh ubuntu@<FLOATING_IP> "curl -s http://169.254.169.254/latest/meta-data/instance-id"

# 5. Verificar storage
openstack volume create --size 10 test-vol
openstack server add volume test-vm test-vol
ssh ubuntu@<FLOATING_IP> "lsblk"  # Should show new disk

# 6. Cleanup
openstack server delete test-vm
openstack volume delete test-vol
openstack router remove subnet test-router test-subnet
openstack router delete test-router
openstack subnet delete test-subnet
openstack network delete test-net
```

### Validação de Rede

```bash
# Verificar OVN
ovn-nbctl show
ovn-sbctl show
ovn-nbctl lr-list
ovn-nbctl ls-list

# Verificar Geneve tunnels
ovs-vsctl show | grep -A2 "Port genev"

# Verificar BGP (nos switches)
# show bgp summary
# show bgp evpn summary
```

### Validação de Storage

```bash
# Swift
swift stat
swift upload test-container /tmp/testfile
swift download test-container testfile -o /tmp/testfile-downloaded
md5sum /tmp/testfile /tmp/testfile-downloaded  # Must match

# Swift replication
swift-recon --replication
swift-recon --unmounted
swift-recon --diskusage

# Cinder
openstack volume create --size 1 --type standard-nvme test-cinder
openstack volume show test-cinder | grep status  # available
openstack volume delete test-cinder
```

---

## Testes de HA

### Teste 1: Failover de Controller

```bash
# Objetivo: Verificar que APIs continuam respondendo com 1 controller down

# 1. Baseline
time openstack token issue  # Record response time

# 2. Stop controller
ssh ctrl-az1fd1-01 "systemctl stop apache2"  # Keystone

# 3. Verify API still works
time openstack token issue  # Should still work (via ctrl-02 or ctrl-03)
openstack server list       # Nova API
openstack network list      # Neutron API

# 4. Verify HAProxy detected failure
curl -s http://10.0.10.5:1936/haproxy?stats | grep ctrl-01  # DOWN

# 5. Restore
ssh ctrl-az1fd1-01 "systemctl start apache2"

# 6. Verify recovery
sleep 10
curl -s http://10.0.10.5:1936/haproxy?stats | grep ctrl-01  # UP
```

### Teste 2: Failover de MariaDB

```bash
# 1. Check current state
mysql -h 10.0.200.5 -e "SHOW STATUS LIKE 'wsrep%';" | grep -E "cluster_size|local_state"

# 2. Kill primary DB node
ssh db-az1fd1-01 "systemctl stop mariadb"

# 3. Verify cluster continues (2/3 quorum)
mysql -h 10.0.200.5 -e "SHOW STATUS LIKE 'wsrep_cluster_size';"  # Expected: 2
openstack token issue  # Should work

# 4. Restart node
ssh db-az1fd1-01 "systemctl start mariadb"

# 5. Verify rejoin
sleep 30
mysql -h 10.0.200.5 -e "SHOW STATUS LIKE 'wsrep_cluster_size';"  # Expected: 3
```

### Teste 3: Failover de RabbitMQ

```bash
# 1. Baseline
rabbitmqctl -n rabbit@mq-az1fd1-01 cluster_status

# 2. Stop one node
ssh mq-az2fd1-01 "systemctl stop rabbitmq-server"

# 3. Verify operations continue
openstack server create --flavor m1.small --image ubuntu-24.04 --network test-net ha-test-vm
# Should succeed (quorum queues tolerate 1 node loss)

# 4. Restart
ssh mq-az2fd1-01 "systemctl start rabbitmq-server"

# 5. Verify
rabbitmqctl -n rabbit@mq-az1fd1-01 cluster_status
```

### Teste 4: Failover de Keepalived VIP

```bash
# 1. Check current MASTER
ip addr show bond0.10 | grep 10.0.10.5  # On lb-01

# 2. Stop keepalived on MASTER
ssh lb-01 "systemctl stop keepalived"

# 3. Verify VIP migrated
ssh lb-02 "ip addr show bond0.10 | grep 10.0.10.5"  # Should be here now

# 4. Verify API access
openstack token issue  # Should work via new VIP holder

# 5. Restore
ssh lb-01 "systemctl start keepalived"
# VIP should return to lb-01 (higher priority)
```

### Teste 5: Compute Node Failure

```bash
# 1. Create VM on specific host
openstack server create --flavor m1.small --image ubuntu-24.04 \
  --network test-net --availability-zone az1::compute-az1fd1-01 ha-vm

# 2. Verify VM is running
openstack server show ha-vm | grep status  # ACTIVE

# 3. Simulate host failure (power off via IPMI)
ipmitool -I lanplus -H 172.16.0.101 -U admin -P PASS power off

# 4. Wait for Nova to detect (fencing timeout)
sleep 120

# 5. Evacuate
nova host-evacuate compute-az1fd1-01

# 6. Verify VM restarted on different host
openstack server show ha-vm | grep "OS-EXT-SRV-ATTR:host"
```

---

## Testes de DR (Disaster Recovery)

### Teste DR-1: Perda de AZ Completa

```bash
# Simular perda de AZ1 (desligar todos os nós de AZ1)
# Impacto esperado:
# - Control plane: 2/3 controllers (quorum mantido)
# - Galera: 2/3 nodes (quorum mantido)
# - RabbitMQ: 2/3 nodes (quorum mantido)
# - Compute: 33% capacity loss
# - Swift: Dados acessíveis (2/3 replicas disponíveis)

# Verificações:
openstack token issue                    # API funcional
openstack server list --all-projects     # VMs em AZ2/AZ3 ok
swift stat                               # Object storage ok
mysql -e "SHOW STATUS LIKE 'wsrep%';"    # Galera 2/3

# Recovery:
# 1. Restaurar energia/rede em AZ1
# 2. Nós rejoinam automaticamente (Galera IST, RabbitMQ cluster)
# 3. VMs em AZ1 precisam ser evacuated ou reiniciadas
```

### Teste DR-2: Backup e Restore de DB

```bash
# Backup
mysqldump --all-databases --single-transaction --routines --triggers \
  -h 10.0.200.5 > /backup/openstack-full-$(date +%Y%m%d).sql

# Restore (em caso de corrupção total)
# 1. Stop all OpenStack services
# 2. Stop Galera cluster
# 3. Bootstrap single node
galera_new_cluster
# 4. Restore
mysql < /backup/openstack-full-YYYYMMDD.sql
# 5. Start remaining nodes
# 6. Start OpenStack services
```

### Teste DR-3: Swift Data Integrity

```bash
# Upload test object
dd if=/dev/urandom of=/tmp/test-1gb bs=1M count=1024
swift upload dr-test /tmp/test-1gb
ORIG_MD5=$(md5sum /tmp/test-1gb | awk '{print $1}')

# Simulate disk failure (remove 1 replica)
ssh swift-az1fd1-01 "umount /srv/node/sdb"

# Verify object still accessible
swift download dr-test test-1gb -o /tmp/test-1gb-recovered
RECV_MD5=$(md5sum /tmp/test-1gb-recovered | awk '{print $1}')
[ "$ORIG_MD5" == "$RECV_MD5" ] && echo "PASS" || echo "FAIL"

# Verify replication repairs
swift-recon --replication  # Should show replication activity
```

---

## Troubleshooting Guide

### API Retornando 503

```bash
# 1. Verificar HAProxy
curl -s http://10.0.10.5:1936/haproxy?stats | grep -E "DOWN|MAINT"

# 2. Verificar backend service
ssh ctrl-01 "systemctl status <service>"
ssh ctrl-01 "journalctl -u <service> --since '5 min ago'"

# 3. Verificar DB connectivity
mysql -h 10.0.200.5 -e "SELECT 1;"

# 4. Verificar RabbitMQ
rabbitmqctl -n rabbit@mq-az1fd1-01 list_queues | head -20
```

### VM Não Inicia (ERROR state)

```bash
# 1. Check Nova logs
openstack server show <VM_ID> --os-compute-api-version 2.latest
openstack server event list <VM_ID>

# 2. Check compute node
ssh <compute_host> "journalctl -u nova-compute --since '5 min ago' | grep <VM_ID>"

# 3. Common causes:
# - No valid host: check scheduler filters
openstack compute service list | grep -v "up.*enabled"
# - Image download failed: check Glance
openstack image show <IMAGE_ID>
# - Network port creation failed: check Neutron
openstack port list --device-id <VM_ID>
```

### Galera Split-Brain

```bash
# Symptoms: wsrep_cluster_status = non-Primary

# 1. Identify which partition has quorum
for node in db-01 db-02 db-03; do
  echo "=== $node ==="
  ssh $node "mysql -e \"SHOW STATUS LIKE 'wsrep_cluster_status';\""
done

# 2. On non-Primary nodes, force rejoin
mysql -e "SET GLOBAL wsrep_provider_options='pc.bootstrap=YES';"
# WARNING: Only do this on the partition with the most recent data!

# 3. Restart non-primary nodes
ssh db-XX "systemctl restart mariadb"
```

### OVN Connectivity Issues

```bash
# 1. Check OVN controller on compute
ssh <compute> "ovs-vsctl get Open_vSwitch . external_ids:ovn-remote"
ssh <compute> "ovn-controller --version"
ssh <compute> "ovs-appctl -t ovn-controller connection-status"  # Should be "connected"

# 2. Check logical flows
ovn-sbctl lflow-list | grep <port_id>

# 3. Check physical flows
ssh <compute> "ovs-ofctl dump-flows br-int | grep <mac_address>"

# 4. Trace packet path
ovn-trace --summary <datapath> 'inport=="<port>" && eth.src==<mac> && ip4.src==<ip>'
```

### Swift Ring Inconsistency

```bash
# 1. Check ring consistency across nodes
for node in $(cat /etc/swift/nodes.list); do
  echo "=== $node ==="
  ssh $node "md5sum /etc/swift/*.ring.gz"
done

# 2. If inconsistent, redistribute from builder node
for node in $(cat /etc/swift/nodes.list); do
  scp /etc/swift/*.ring.gz ${node}:/etc/swift/
  ssh $node "systemctl restart swift-*"
done
```

### High API Latency

```bash
# 1. Check HAProxy stats
curl -s http://10.0.10.5:1936/haproxy?stats | grep -E "qcur|scur|rate"

# 2. Check DB slow queries
mysql -e "SHOW PROCESSLIST;" | grep -v Sleep
mysql -e "SHOW GLOBAL STATUS LIKE 'Slow_queries';"

# 3. Check RabbitMQ queue depth
rabbitmqctl list_queues name messages | sort -k2 -rn | head -10

# 4. Check system resources
ssh ctrl-01 "top -bn1 | head -20"
ssh ctrl-01 "iostat -x 1 3"
```

---

## Métricas de Sucesso

| Teste | Critério de Sucesso | RTO |
|-------|--------------------|----|
| Controller failover | API disponível em < 5s | 5s |
| DB failover | Queries funcionam em < 10s | 10s |
| MQ failover | Messages delivered em < 30s | 30s |
| VIP failover | Connectivity restored < 3s | 3s |
| Compute evacuation | VMs running on new host < 5min | 5min |
| AZ loss | Remaining AZs functional < 1min | 1min |
| Full DB restore | Services operational < 30min | 30min |

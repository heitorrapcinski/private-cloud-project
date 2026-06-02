---
name: kvm-ops
description: >
  Operate, monitor, and troubleshoot the KVM/QEMU/libvirt virtualization layer.
  Use this skill for: diagnosing VM failures, inspecting running VM state,
  troubleshooting live migration errors, monitoring KVM performance, managing
  VM lifecycle (pause, resume, save, restore, snapshot), diagnosing storage I/O
  issues, collecting QEMU/libvirt logs, checking KVM statistics, managing
  hugepages under pressure, diagnosing vCPU steal, managing NUMA imbalance,
  or troubleshooting VNC/SPICE/console access. Triggers on: "my VM is stuck in
  paused state", "live migration fails with error X", "how do I check vCPU
  utilization per VM", "virsh list shows the VM as running but it's not
  responding", "how do I take a live snapshot without downtime", "QEMU process
  is consuming 100% CPU on one core", "how do I check KVM exit stats", "VM
  disk I/O is slow — how to diagnose", "how do I monitor hugepage usage per
  VM", "libvirtd crashed — how to recover", "how to force-kill a stuck
  migration", "inspect domain XML of a running VM", "check NUMA placement of
  a running VM", "how to send QMP commands to a running QEMU process".
---

# KVM / QEMU / libvirt Operations Guide

Local repositories (for source reference during troubleshooting):
```
repos\kvm\
  linux\          ← Linux v6.19.14 (sparse KVM checkout)
  qemu\           ← QEMU v11.0.1
  libvirt\        ← libvirt v12.4.0
  libvirt-python\ ← libvirt-python v12.4.0
```
All path references below are relative to each repo root.

---

## VM lifecycle — virsh quick reference

```bash
virsh list --all                        # list all VMs (running + stopped)
virsh start    <domain>                 # start VM
virsh shutdown <domain>                 # ACPI shutdown (graceful)
virsh destroy  <domain>                 # force-kill (like power off)
virsh suspend  <domain>                 # pause vCPUs (SIGSTOP to QEMU)
virsh resume   <domain>                 # resume paused VM
virsh save     <domain> /tmp/vm.state   # save to disk (stops VM)
virsh restore  /tmp/vm.state            # restore from saved state
virsh reboot   <domain>                 # ACPI reboot
virsh reset    <domain>                 # hard reset (no ACPI)

virsh dumpxml  <domain>                 # domain XML of running VM
virsh dominfo  <domain>                 # summary: state, memory, vCPUs
virsh domstats <domain>                 # all stats: cpu, memory, disk, net
virsh vcpuinfo <domain>                 # vCPU → pCPU mapping + time
virsh numatune <domain>                 # NUMA placement of running VM
```

## Health checks

### KVM module
```bash
lsmod | grep kvm                        # kvm, kvm_intel / kvm_amd
cat /proc/cpuinfo | grep -E "vmx|svm"  # hardware virt support
ls -la /dev/kvm                         # must exist
```

### libvirtd
```bash
systemctl status libvirtd               # service status
journalctl -u libvirtd -n 100          # recent logs
virsh connect qemu:///system           # test connection

# List all capabilities
virsh capabilities
virsh domcapabilities                   # QEMU capabilities for new VMs
```

### QEMU process per VM
```bash
# Find QEMU process
pgrep -a qemu                           # all QEMU processes with args
ps -eo pid,ppid,pcpu,pmem,cmd | grep qemu-system

# QEMU log (libvirt-managed)
cat /var/log/libvirt/qemu/<domain>.log

# QEMU PID for a domain
virsh dumpxml <domain> | grep "pid"
# or
cat /var/run/libvirt/qemu/<domain>.pid
```

## Performance monitoring

### vCPU statistics
```bash
virsh domstats <domain> --vcpu
# vcpu.0.state, vcpu.0.time, vcpu.0.wait, vcpu.0.halted

# Per-vCPU CPU time
virsh vcpuinfo <domain>

# Real-time vCPU steal (using perf)
perf kvm stat -p $(cat /var/run/libvirt/qemu/<domain>.pid)

# vCPU to pCPU mapping
virsh vcpupin <domain>
```

### KVM exit statistics (performance bottleneck indicator)
```bash
# Per-VM KVM exits (requires debugfs)
cat /sys/kernel/debug/kvm/<pid>-<fd>/exits

# Or use kvm_stat tool (from linux/tools/kvm/)
kvm_stat --log            # continuous log of all KVM exit reasons
kvm_stat --fields exits   # filter to exit counts

# Exit reasons to watch:
#   HLT       — halt exits (normal vCPU idle)
#   EXTERNAL_INTERRUPT — host interrupt during guest execution
#   EPT_MISCONFIG / EPT_VIOLATION — EPT page table events
#   MSR_READ/WRITE — frequent MSR exits indicate emulation overhead
```
Source: `linux/arch/x86/kvm/vmx/vmx.c` — `EXIT_REASON_*` constants.

### Memory monitoring
```bash
# Hugepages global
cat /sys/kernel/mm/hugepages/hugepages-2048kB/free_hugepages
cat /sys/kernel/mm/hugepages/hugepages-1048576kB/free_hugepages

# Per-VM balloon stats
virsh dommemstat <domain>
# actual, swap_in, swap_out, major_fault, minor_fault, rss, available, usable

# NUMA memory placement of a VM
cat /proc/$(cat /var/run/libvirt/qemu/<domain>.pid)/numa_maps | head -20

# KSM stats
cat /sys/kernel/mm/ksm/pages_shared
cat /sys/kernel/mm/ksm/pages_sharing
```

### Disk I/O monitoring
```bash
virsh domblkstat <domain> vda
# rd_req, rd_bytes, wr_req, wr_bytes, flush_operations, rd_total_times, wr_total_times

# I/O latency via iostat
iostat -x 1 10 /dev/sda

# QEMU block info via QMP
virsh qemu-monitor-command <domain> --pretty '{"execute":"query-blockstats"}'
```

### Network monitoring
```bash
virsh domifstat <domain> vnet0
# rx_bytes, rx_packets, rx_errs, rx_drop, tx_bytes, tx_packets

# TAP device stats
ip -s link show vnet0
```

## Diagnostics

### VM stuck in paused state
```bash
virsh domstate <domain>          # should say "paused"
virsh dominfo  <domain>          # check reason field

# Common causes:
# 1. Disk full (I/O error): check QEMU log
cat /var/log/libvirt/qemu/<domain>.log | grep -i "error\|i/o\|eio"

# 2. Memory pressure (host OOM)
dmesg | grep -i "oom\|killed"

# 3. Migration paused waiting for destination
virsh domjobinfo <domain>        # shows migration progress / error

# Resume if safe:
virsh resume <domain>
```

### Live migration failure
```bash
# Check migration status
virsh domjobinfo <domain>

# Common errors:
# "Unable to read from monitor" → QEMU crashed on destination
# "migration was active, but no RAM was transferred" → network issue
# "blocked by MigrationBlocked" → device state cannot be serialised

# Cancel stuck migration
virsh domjobabort <domain>

# Check destination side
virsh -c qemu+ssh://dest-host/system list

# Migration logs
tail -f /var/log/libvirt/qemu/<domain>.log
journalctl -u libvirtd -f
```
Source: `qemu/migration/migration.c` — state machine + error codes.

### High vCPU steal / QEMU CPU 100%
```bash
# Identify which vCPU thread is pegged
ps -eLo pid,lwp,pcpu,comm | grep qemu-system | sort -k3 -rn | head

# Map thread ID to vCPU number
virsh vcpuinfo <domain>   # shows thread IDs

# Check for excessive KVM exits
kvm_stat                   # look for elevated EXTERNAL_INTERRUPT or MSR exits

# Check if IRQ balancing is interfering
cat /proc/interrupts | grep -E "eth|virtio|ahci"
service irqbalance stop    # temporarily disable for testing
```

### NUMA imbalance
```bash
# Check if VM memory crosses NUMA nodes
virsh numatune <domain>
cat /proc/$(cat /var/run/libvirt/qemu/<domain>.pid)/numa_maps | grep ^7

# Check host NUMA memory distribution
numastat -p $(cat /var/run/libvirt/qemu/<domain>.pid)

# Repin at runtime (no downtime)
virsh numatune <domain> --nodeset 0 --mode strict
virsh vcpupin  <domain> 0 "0-7"
```

## Snapshots

```bash
# Live snapshot (external — recommended, no downtime)
virsh snapshot-create-as <domain> snap1 \
  --disk-only --atomic \
  --diskspec vda,snapshot=external,file=/var/lib/libvirt/images/snap1.qcow2

# List snapshots
virsh snapshot-list <domain>

# Revert to snapshot
virsh snapshot-revert <domain> snap1 --running

# Delete snapshot and merge (blockcommit)
virsh blockcommit <domain> vda --active --pivot --verbose
virsh snapshot-delete <domain> snap1 --metadata
```

## QMP — direct QEMU monitor access

```bash
# Connect to running VM's QMP socket
virsh qemu-monitor-command <domain> --pretty '{"execute":"query-status"}'
virsh qemu-monitor-command <domain> --pretty '{"execute":"query-cpus-fast"}'
virsh qemu-monitor-command <domain> --pretty '{"execute":"query-block"}'
virsh qemu-monitor-command <domain> --pretty '{"execute":"query-migrate"}'
virsh qemu-monitor-command <domain> --pretty '{"execute":"query-balloon"}'

# Inject NMI (diagnose hung guest)
virsh inject-nmi <domain>

# Set migration bandwidth cap
virsh qemu-monitor-command <domain> --pretty \
  '{"execute":"migrate-set-parameters","arguments":{"max-bandwidth":104857600}}'
```
QMP schema: `qemu/qapi/qapi-schema.json`

## libvirtd recovery

```bash
# libvirtd can restart without killing VMs (stateful daemon restart)
systemctl restart libvirtd

# If libvirtd crashed and VMs are still running (QEMU processes alive):
# VMs will reconnect automatically when libvirtd restarts

# Emergency: reconnect to orphaned QEMU process
# The monitor socket is at: /var/run/libvirt/qemu/<domain>.monitor
virsh start <domain>   # will detect existing QEMU pid and reconnect
```

## Log locations

| Component | Log location |
|---|---|
| libvirtd | `/var/log/libvirt/libvirtd.log` or `journalctl -u libvirtd` |
| QEMU per VM | `/var/log/libvirt/qemu/<domain>.log` |
| KVM (kernel) | `dmesg \| grep kvm` or `journalctl -k \| grep kvm` |
| Nova libvirt driver | `/var/log/nova/nova-compute.log` |
| swtpm (vTPM) | `/var/log/swtpm/libvirt/qemu/<domain>-swtpm.log` |

## Response format

1. **Immediate diagnostic commands** — what to run right now to assess the situation.
2. **Likely root causes** — ordered by frequency, each with distinguishing symptom.
3. **Source reference** — which QEMU/KVM file implements the failing component.
4. **Remediation** — exact commands. Include QMP commands when applicable.
5. **Prevention** — config option or design choice that avoids recurrence.

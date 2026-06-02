---
name: kvm-build
description: >
  Configure and deploy KVM, QEMU, and libvirt — the virtualization layer
  beneath OpenStack. Use this skill for: tuning KVM performance (hugepages,
  CPU pinning, NUMA, nested), configuring QEMU features (machine type, firmware,
  vTPM, SR-IOV, vhost-user), writing or editing libvirt domain XML, configuring
  libvirtd (auth, TLS, migration parameters), tuning Nova libvirt driver
  settings (nova.conf [libvirt] section), configuring storage backends (qcow2,
  RBD, raw), or setting up virtio/vhost. Triggers on: "how do I enable
  hugepages for KVM", "configure CPU pinning for real-time VMs", "enable
  nested virtualization", "configure libvirt for live migration over TLS",
  "what Nova config controls the QEMU machine type", "how to enable vTPM in
  domain XML", "configure vhost-user with OVS-DPDK", "tune KSM for memory
  overcommit", "configure QEMU with Ceph/RBD backend", "enable AMD SEV
  encryption", "set up CPU model passthrough", "configure NUMA topology in
  domain XML", "enable SR-IOV in libvirt". Always read actual config files
  and domain XML schemas from the source — never invent option names.
---

# KVM / QEMU / libvirt Build & Configuration Guide

Local repositories (cloned at latest stable, 2026):
```
repos\kvm\
  linux\          ← Linux v6.19.14 — sparse: virt/kvm, arch/x86/kvm, include, Documentation/virt/kvm
  qemu\           ← QEMU v11.0.1
  libvirt\        ← libvirt v12.4.0
  libvirt-python\ ← libvirt-python v12.4.0
```

Nova libvirt driver config reference:
```
openstack-repos\openstack\nova\nova\conf\libvirt.py   ← all [libvirt] options with help= text
```

All path references below are relative to each repo root.

---

## Part 1 — KVM Kernel Module

### Enable KVM
```bash
# Load modules
modprobe kvm
modprobe kvm_intel   # or kvm_amd

# Verify
ls /dev/kvm
cat /sys/module/kvm_intel/parameters/nested   # nested virt status
```

### Nested virtualization
```bash
# Intel — enable at load time (or /etc/modprobe.d/kvm.conf)
echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-intel.conf
modprobe -r kvm_intel && modprobe kvm_intel

# AMD
echo "options kvm_amd nested=1" > /etc/modprobe.d/kvm-amd.conf

# Verify
cat /sys/module/kvm_intel/parameters/nested   # should be Y or 1
```
Source: `linux/arch/x86/kvm/vmx/vmx.c` — `nested` module param.

### KVM kernel parameters (tuning)
```bash
# /sys/module/kvm/parameters/
halt_poll_ns         # vCPU halt polling (default 500000 ns) — reduce for latency
halt_poll_ns_grow    # growth factor when polling succeeds
halt_poll_ns_shrink  # shrink factor when polling misses

# /sys/module/kvm_intel/parameters/
ept                  # Extended Page Tables (should stay 1)
vpid                 # VPID (TLB tagging per VM — keep 1)
flexpriority         # flexible priority (keep 1)
posted_intr          # posted interrupts (keep 1 for low-latency IRQ delivery)
```

### Hugepages
```bash
# Allocate 1G hugepages at boot (grub: hugepagesz=1G hugepages=64)
# or 2M hugepages at runtime:
echo 2048 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
mount -t hugetlbfs hugetlbfs /dev/hugepages

# NUMA-aware allocation:
echo 1024 > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
echo 1024 > /sys/devices/system/node/node1/hugepages/hugepages-2048kB/nr_hugepages
```

### KSM (Kernel Samepage Merging — memory overcommit)
```bash
echo 1     > /sys/kernel/mm/ksm/run          # enable KSM
echo 1000  > /sys/kernel/mm/ksm/pages_to_scan
echo 20    > /sys/kernel/mm/ksm/sleep_millisecs
cat /sys/kernel/mm/ksm/pages_shared          # pages currently shared
```

---

## Part 2 — QEMU Configuration

### Machine type selection
```bash
# List available machine types
qemu-system-x86_64 -M help

# Recommended for OpenStack/production (2026):
#   q35         — PCIe chipset (default in modern libvirt)
#   pc-i440fx-* — legacy chipset (avoid for new VMs)
```
Source: `qemu/hw/i386/` — `pc.c`, `q35.c`.

### CPU model
```bash
# List available CPU models
qemu-system-x86_64 -cpu help

# Recommended options:
# host        — pass-through host CPU (best perf, requires same-CPU live migration)
# EPYC-v4     — AMD generic baseline (safe for live migration across AMD)
# Cascadelake-Server — Intel generic baseline
# max         — all features supported by accelerator
```

### UEFI firmware (OVMF)
```bash
# QEMU CLI: use pflash for UEFI + nvram
-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
-drive if=pflash,format=raw,file=/var/lib/libvirt/qemu/nvram/vm-VARS.fd
```
Libvirt domain XML equivalent (see Part 3).

### vTPM
```bash
# Requires swtpm daemon
swtpm socket --tpmstate dir=/var/lib/libvirt/swtpm/vm/ \
  --ctrl type=unixio,path=/var/lib/libvirt/swtpm/vm/swtpm.sock \
  --tpm2

# QEMU CLI:
-chardev socket,id=chrtpm,path=/var/lib/libvirt/swtpm/vm/swtpm.sock \
-tpmdev emulator,id=tpm0,chardev=chrtpm \
-device tpm-tis,tpmdev=tpm0
```

### Ceph/RBD block backend
```bash
# QEMU directly (without libvirt)
-drive driver=rbd,pool=vms,image=vm-disk,id=drive0 \
       format=raw,if=virtio,cache=none,aio=native
```

### virtio-net with vhost
```bash
-netdev tap,id=net0,vhost=on,script=no,downscript=no \
-device virtio-net-pci,netdev=net0,mq=on,vectors=10
```

### vhost-user (OVS-DPDK / DPDK backend)
```bash
# Requires running vhost-user socket provider (e.g., OVS-DPDK)
-chardev socket,id=chr0,path=/var/run/openvswitch/vm0.sock \
-netdev vhost-user,chardev=chr0,id=net0,queues=4 \
-device virtio-net-pci,netdev=net0,mq=on,vectors=10
-object memory-backend-memfd,id=mem,size=4G,share=on \
-numa node,memdev=mem
```
Source: `qemu/hw/virtio/vhost-user.c`, `qemu/net/vhost-user.c`.

---

## Part 3 — libvirt Domain XML

### Reference: full domain XML schema
```
libvirt/docs/schemas/domain.rng       ← RelaxNG schema (authoritative)
libvirt/src/conf/domain_conf.c        ← parser (field names match XML tags exactly)
```

### CPU configuration
```xml
<!-- CPU passthrough — best performance, requires homogeneous cluster for migration -->
<cpu mode="host-passthrough" check="none">
  <topology sockets="1" cores="4" threads="2"/>
</cpu>

<!-- Custom model — safe for live migration across similar CPUs -->
<cpu mode="custom" match="exact">
  <model fallback="forbid">Cascadelake-Server</model>
  <feature policy="require" name="vmx"/>
</cpu>
```

### NUMA topology
```xml
<cpu>
  <topology sockets="2" cores="8" threads="2"/>
  <numa>
    <cell id="0" cpus="0-15" memory="16384" unit="MiB" memAccess="shared"/>
    <cell id="1" cpus="16-31" memory="16384" unit="MiB" memAccess="shared"/>
  </numa>
</cpu>
<numatune>
  <memory mode="strict" nodeset="0-1"/>
  <memnode cellid="0" mode="strict" nodeset="0"/>
  <memnode cellid="1" mode="strict" nodeset="1"/>
</numatune>
```

### CPU pinning (real-time / low-latency)
```xml
<cputune>
  <vcpupin vcpu="0" cpuset="2"/>
  <vcpupin vcpu="1" cpuset="3"/>
  <emulatorpin cpuset="0-1"/>
  <iothreadpin iothread="1" cpuset="4"/>
</cputune>
```

### Hugepages
```xml
<memoryBacking>
  <hugepages>
    <page size="1" unit="GiB" nodeset="0"/>
  </hugepages>
  <locked/>          <!-- prevents swapping -->
  <nosharepages/>    <!-- disables KSM for this VM -->
</memoryBacking>
```

### UEFI + Secure Boot
```xml
<os firmware="efi">
  <type arch="x86_64" machine="q35">hvm</type>
  <firmware>
    <feature enabled="yes" name="secure-boot"/>
    <feature enabled="yes" name="enrolled-keys"/>
  </firmware>
</os>
```

### vTPM
```xml
<tpm model="tpm-tis">
  <backend type="emulator" version="2.0">
    <encryption secret="uuid-of-secret"/>
  </backend>
</tpm>
```

### virtio disk with IO thread
```xml
<disk type="file" device="disk">
  <driver name="qemu" type="qcow2" cache="none" io="native" iothread="1"/>
  <source file="/var/lib/libvirt/images/vm.qcow2"/>
  <target dev="vda" bus="virtio"/>
</disk>
<iothreads>1</iothreads>
```

### Ceph/RBD disk (libvirt → QEMU → librbd)
```xml
<disk type="network" device="disk">
  <driver name="qemu" type="raw" cache="none" discard="unmap"/>
  <source protocol="rbd" name="vms/vm-disk">
    <host name="ceph-mon1" port="6789"/>
    <host name="ceph-mon2" port="6789"/>
    <auth username="cinder">
      <secret type="ceph" uuid="ceph-secret-uuid"/>
    </auth>
  </source>
  <target dev="vda" bus="virtio"/>
</disk>
```

### virtio-net with vhost
```xml
<interface type="bridge">
  <source bridge="br0"/>
  <model type="virtio"/>
  <driver name="vhost" queues="4"/>
  <tune>
    <sndbuf>0</sndbuf>
  </tune>
</interface>
```

### AMD SEV (memory encryption)
```xml
<launchSecurity type="sev">
  <policy>0x0003</policy>         <!-- 0x0001=no-debug 0x0002=no-send -->
  <cbitpos>47</cbitpos>
  <reducedPhysBits>1</reducedPhysBits>
</launchSecurity>
```
Requires: `linux/arch/x86/kvm/svm/sev.c` — SEV must be enabled in BIOS.

---

## Part 4 — libvirtd Configuration

### /etc/libvirt/libvirtd.conf (key options)
```ini
listen_tls = 1
listen_tcp = 0
tls_port = "16514"
ca_file    = "/etc/pki/CA/cacert.pem"
cert_file  = "/etc/pki/libvirt/servercert.pem"
key_file   = "/etc/pki/libvirt/private/serverkey.pem"

auth_tls = "sasl"          # or "none" for cert-only auth
max_clients = 1024
min_workers = 5
max_workers = 20
```

### /etc/libvirt/qemu.conf (key options)
```ini
vnc_listen   = "0.0.0.0"
spice_listen = "0.0.0.0"
user  = "qemu"             # QEMU process user
group = "qemu"

# Cgroup device ACL for passthrough
cgroup_device_acl = [
    "/dev/kvm", "/dev/vfio/vfio",
    "/dev/net/tun", "/dev/rtc"
]

# Memory locking for hugepages
lock_manager = "lockd"
```

### Migration parameters (libvirtd)
```ini
# /etc/libvirt/libvirtd.conf
migration_address = "10.0.0.10"    # source-side bind address for migration
```

---

## Part 5 — Nova [libvirt] Config (nova.conf)

All options defined in: `nova/nova/conf/libvirt.py`

```ini
[libvirt]
virt_type           = kvm            # kvm | qemu | xen | lxc
cpu_mode            = host-passthrough  # host-passthrough | host-model | custom | none
cpu_model           = Cascadelake-Server  # used when cpu_mode=custom
connection_uri      = qemu:///system
live_migration_scheme = tls          # tls | ssh | native
live_migration_parallel_connections = 2   # Gazpacho 2026.1+
disk_cachemodes     = "file=none,block=none"
image_type          = qcow2          # qcow2 | raw
images_type         = default
hw_disk_discard     = unmap          # enables thin provisioning reclaim
mem_stats_period_seconds = 10
sysinfo_serial      = unique
num_pcie_ports      = 16            # number of PCIe root ports on q35

# vTPM (requires swtpm)
swtpm_enabled       = True
swtpm_user          = swtpm
swtpm_group         = swtpm

# SR-IOV
[pci]
passthrough_whitelist = [{"vendor_id":"8086","product_id":"1515"}]
alias = [{"vendor_id":"8086","product_id":"1515","device_type":"type-PF","name":"sriov-nic"}]
```

## Response format

1. **Configuration option** with its file, section, and default value (from source).
2. **Effect**: what the option controls and when to change it.
3. **Domain XML snippet** (if libvirt-related) — copy-pasteable, minimal.
4. **Source reference**: file path where the option is defined or the feature is implemented.
5. **Interaction with OpenStack**: how the nova.conf setting maps to the libvirt/QEMU behaviour.

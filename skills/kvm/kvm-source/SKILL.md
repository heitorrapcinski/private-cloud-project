---
name: kvm-source
description: >
  Navigate and understand KVM, QEMU, and libvirt source code — the full
  virtualization stack beneath OpenStack Nova. Use this skill whenever the
  user asks WHERE something is implemented, HOW it works internally, or wants
  to trace an execution path across the KVM stack. Triggers on: "how does KVM
  handle a VM exit", "where is live migration implemented in QEMU", "how does
  libvirt build the domain XML", "trace a vCPU halt", "how does virtio-blk
  work at the QEMU level", "where does KVM handle EPT violations", "how does
  QEMU implement VFIO passthrough", "explain the libvirt virDomainMigrate call
  chain", "how does KVM handle nested virtualization", "where is
  memory ballooning implemented", "how does QEMU implement the virtio-net
  device", "trace a KVM_RUN ioctl", "how does libvirt talk to QEMU via QMP",
  "where is the QEMU block layer", "how does KVM implement posted interrupts".
  Always read the actual source — never invent struct fields or ioctl numbers.
---

# KVM / QEMU / libvirt Source Explorer

Local repositories (cloned at latest stable, 2026):
```
repos\kvm\
  linux\          ← Linux v6.19.14 — sparse: virt/kvm, arch/x86/kvm, include, Documentation/virt/kvm
  qemu\           ← QEMU v11.0.1 — full clone
  libvirt\        ← libvirt v12.4.0 — full clone
  libvirt-python\ ← libvirt-python v12.4.0 — full clone
```

Also relevant — Nova libvirt driver (OpenStack side):
```
repos\openstack\openstack\nova\nova\virt\libvirt\
```

All path references below are relative to each repo root.

## Stack overview

```
┌─────────────────────────────────────────────────────┐
│  OpenStack Nova  (nova/virt/libvirt/driver.py)       │  orchestration
├─────────────────────────────────────────────────────┤
│  libvirt  (libvirtd / virtqemud)                     │  domain XML → QEMU CLI
├─────────────────────────────────────────────────────┤
│  QEMU  (qemu-system-x86_64)                          │  device emulation + KVM ioctls
├─────────────────────────────────────────────────────┤
│  KVM kernel module  (virt/kvm + arch/x86/kvm)        │  hardware virt (VT-x / AMD-V)
└─────────────────────────────────────────────────────┘
```

---

## Linux kernel — KVM subsystem

### Key directories (sparse checkout)
```
linux/virt/kvm/          ← architecture-independent KVM core
  kvm_main.c             ← KVM_CREATE_VM, KVM_CREATE_VCPU, KVM_RUN main loop
  irqchip.c              ← in-kernel irqchip (APIC/PIC emulation)
  async_pf.c             ← async page fault handling
  coalesced_mmio.c       ← batching of MMIO exits
  eventfd.c              ← ioeventfd / irqfd kernel interfaces
  dirty_ring.c           ← dirty page tracking (ring buffer API)
  mmu/                   ← shadow paging + EPT/NPT page table management
    mmu.c                ← main MMU walker
    tdp_mmu.c            ← TDP (two-dimensional paging) MMU — modern path

linux/arch/x86/kvm/      ← x86-specific KVM
  vmx/                   ← Intel VT-x
    vmx.c                ← VMCS setup, vmlaunch/vmresume, VM-exit dispatch
    nested.c             ← nested virtualization (L1/L2 guests)
    posted_interrupt.c   ← posted interrupt processing
  svm/                   ← AMD-V / SVM
    svm.c                ← VMCB setup, #VMEXIT dispatch
    nested.c             ← nested SVM
  emulate.c              ← instruction emulator (for exits that need it)
  mmu/                   ← x86 MMU (EPT, NPT, shadow)
  lapic.c                ← local APIC emulation
  ioapic.c               ← I/O APIC emulation
  pmu.c                  ← PMU (perf counter) virtualization

linux/include/uapi/linux/kvm.h   ← userspace ABI: all KVM ioctls + structs
linux/include/linux/kvm_host.h   ← kernel-internal KVM structs (struct kvm, struct kvm_vcpu)
linux/Documentation/virt/kvm/   ← ABI documentation, API extensions
```

### How to search KVM source
```
VM exit handler:    Grep "case EXIT_REASON_" in arch/x86/kvm/vmx/vmx.c
ioctl entry point:  Grep "case KVM_" in virt/kvm/kvm_main.c
vcpu struct fields: Read include/linux/kvm_host.h → struct kvm_vcpu
userspace ABI:      Read include/uapi/linux/kvm.h → KVM_* constants
```

### KVM_RUN execution path
```
userspace: ioctl(vcpu_fd, KVM_RUN, 0)
  → virt/kvm/kvm_main.c::kvm_vcpu_ioctl() → kvm_arch_vcpu_ioctl_run()
  → arch/x86/kvm/x86.c::vcpu_run()
  → arch/x86/kvm/vmx/vmx.c::vmx_vcpu_run()  (Intel) / svm.c::svm_vcpu_run() (AMD)
  → VMLAUNCH / VMRESUME  →  guest runs
  → VM-exit → vmx_handle_exit() → per-reason handler
  → back to userspace (or re-enter if handled in kernel)
```

### EPT violation (page fault in guest physical space)
```
arch/x86/kvm/vmx/vmx.c::handle_ept_violation()
  → virt/kvm/mmu/mmu.c::kvm_mmu_page_fault()
  → tdp_mmu.c::kvm_tdp_mmu_page_fault()  (modern path)
  → map host page → update EPT entry
```

---

## QEMU

### Key directories
```
qemu/accel/kvm/       ← KVM accelerator integration
  kvm-all.c           ← kvm_init(), kvm_vcpu_exec(), ioctl wrappers
  kvm-cpus.c          ← vCPU thread lifecycle

qemu/target/i386/kvm/ ← x86-specific KVM setup
  kvm.c               ← CPUID, MSRs, APIC, VMX/SVM capability negotiation
  kvm-cpu.c           ← CPU model mapping

qemu/hw/virtio/       ← virtio device implementations
  virtio.c            ← virtio core (vring, kicks, irqs)
  virtio-blk.c        ← virtio-blk (disk) backend
  virtio-net.c        ← virtio-net (network) backend
  virtio-balloon.c    ← memory ballooning
  virtio-gpu.c        ← virtio-gpu (display)
  vhost*.c            ← vhost offload to host kernel / vhost-user

qemu/hw/block/        ← block device backends
  nvme.c              ← NVMe emulation
  virtio-blk.c        ← (see above)

qemu/block/           ← QEMU block layer (I/O stack)
  block.c             ← top-level block API
  qcow2.c             ← QCOW2 image format
  raw-posix.c         ← raw/file backend
  nbd.c               ← NBD protocol

qemu/migration/       ← live migration
  migration.c         ← migration state machine
  savevm.c            ← VM state serialization (save/load)
  ram.c               ← RAM transfer (precopy, postcopy)
  postcopy-ram.c      ← postcopy mode
  channel-block.c     ← migration channel over TCP/UNIX

qemu/hw/net/          ← network device emulation
  e1000.c             ← Intel e1000 emulation
  virtio-net.c        ← (see above)

qemu/chardev/         ← character devices (serial, PTY, socket)
qemu/hw/display/      ← display devices (VGA, Bochs, QXL)
qemu/hw/usb/          ← USB controllers + devices
qemu/hw/pci/          ← PCI bus + PCIe
qemu/hw/vfio/         ← VFIO device passthrough

qemu/qapi/            ← QMP (QEMU Monitor Protocol) API definitions
  qapi-schema.json    ← all QMP commands and events (JSON schema)
```

### How to search QEMU source
```
QMP command:      Grep "QOBJECT_CLASS\|QMP_COMMAND\|qmp_" in qapi/
Device model:     Grep "type_register_static\|DEFINE_DEVICE" in hw/*/
ioctl to KVM:     Grep "kvm_vcpu_ioctl\|kvm_vm_ioctl" in accel/kvm/ target/i386/kvm/
virtio ring ops:  Read hw/virtio/virtio.c → virtio_queue_*
Live migration:   Read migration/ram.c → ram_save_iterate()
VFIO passthrough: Read hw/vfio/pci.c
```

### Live migration execution path (QEMU)
```
qmp_migrate() → migration/migration.c::migrate_start()
  → migration state machine: SETUP → ACTIVE → POSTCOPY/COMPLETE
  → migration/ram.c::ram_save_iterate()   ← iterative dirty-page copy
  → migration/savevm.c::vmstate_save()    ← device state
  → target side: migration/migration.c::process_incoming_migration()
```

### QEMU–KVM interaction loop
```
qemu/accel/kvm/kvm-all.c::kvm_cpu_exec()
  loop:
    ioctl(vcpu_fd, KVM_RUN)              ← enter guest
    switch(run->exit_reason):
      KVM_EXIT_IO       → cpu_outb/inb handlers
      KVM_EXIT_MMIO     → address_space_rw (device emulation)
      KVM_EXIT_IRQ_*    → apic/irqchip update
      KVM_EXIT_SHUTDOWN → shutdown VM
```

---

## libvirt

### Key directories
```
libvirt/src/qemu/         ← QEMU driver (most relevant for OpenStack)
  qemu_driver.c           ← main entry point (virDomainCreate*, virDomainMigrate*)
  qemu_domain.c           ← domain object lifecycle
  qemu_command.c          ← builds the QEMU command line from domain XML
  qemu_monitor.c          ← QMP connection management
  qemu_monitor_json.c     ← QMP JSON command dispatch
  qemu_migration.c        ← live migration orchestration
  qemu_capabilities.c     ← QEMU capability probing (qemu -M help, qemu -device help)
  qemu_hotplug.c          ← device hotplug/unplug (disk, NIC, memory)
  qemu_snapshot.c         ← snapshot management
  qemu_block.c            ← block device configuration

libvirt/src/conf/         ← domain XML parsing/formatting
  domain_conf.c           ← virDomainDef — the in-memory domain definition
  domain_conf.h           ← all domain XML struct definitions
  cpu_conf.c              ← CPU model parsing

libvirt/src/libvirt.c     ← public API entry points (virDomain*, virNetwork*, etc.)
libvirt/include/libvirt/  ← public C API headers

libvirt/src/remote/       ← libvirt RPC (client ↔ libvirtd)
  remote_driver.c         ← remote client driver
  remote.x                ← XDR-based RPC protocol definition

libvirt/tools/
  virsh.c                 ← virsh CLI tool
```

### How to search libvirt source
```
API call path:    Grep "virDomainCreate\b" in src/libvirt.c → src/qemu/qemu_driver.c
Domain XML field: Grep "field_name" in src/conf/domain_conf.c
QMP command sent: Grep "qemuMonitorJSON" in src/qemu/qemu_monitor_json.c
Migration:        Read src/qemu/qemu_migration.c → qemuMigrationSrcPerformJob()
```

### libvirt → QEMU → KVM call chain (domain start)
```
virDomainCreate()
  → src/libvirt.c → RPC → libvirtd
  → src/qemu/qemu_driver.c::qemuDomainObjStart()
  → src/qemu/qemu_command.c::qemuBuildCommandLine()   ← builds QEMU CLI args from XML
  → fork + exec qemu-system-x86_64 ...
  → src/qemu/qemu_monitor.c  ← open QMP socket to QEMU
  → QMP: "cont" command → QEMU calls KVM_RUN
```

---

## Nova libvirt driver (OpenStack integration)

```
nova/virt/libvirt/
  driver.py          ← main driver: spawn(), live_migration(), snapshot()
  config.py          ← LibvirtConfigGuest* — Python domain XML builder
  guest.py           ← thin wrapper over libvirt Python API
  host.py            ← host capabilities (CPU models, NUMA topology)
  imagebackend.py    ← image formats (qcow2, raw, rbd)
  vif.py             ← VIF plug/unplug (virtio, SR-IOV, vhostuser)
  volume/            ← volume attachment drivers (RBD, iSCSI, FC)
  migration/         ← live migration helpers (pre/post migration)
```

### Nova spawn() → QEMU path
```
nova/virt/libvirt/driver.py::spawn()
  → _create_domain_and_network()
  → to_xml()  →  nova/virt/libvirt/config.py  (builds domain XML)
  → guest.create()  →  libvirt.virDomainCreateXML()
  → libvirtd → qemu-system-x86_64 → KVM_CREATE_VM + KVM_RUN
```

## Response format

1. **File path(s)** where the implementation lives (with line reference when useful).
2. **Relevant code snippet** — key structs, functions, or enums.
3. **Plain-language explanation** including why the code is structured that way.
4. **Cross-layer connections** — if a QEMU function calls a KVM ioctl, show both sides. If Nova calls libvirt, show the libvirt side.

Always prefer reading a specific short excerpt over summarising from memory.

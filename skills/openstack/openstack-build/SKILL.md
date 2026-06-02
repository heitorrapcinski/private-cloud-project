---
name: openstack-build
description: >
  Configure, deploy, and extend OpenStack — covering both operators who need
  to tune a running cloud and developers who need to write new plugins. Use
  this skill when the user wants to CONFIGURE a service (oslo.config options,
  nova.conf, neutron.conf), DEPLOY with Kolla-Ansible (globals.yml, inventory,
  kolla-genpwd, deploy steps), WRITE a new plugin or driver (nova virt driver,
  neutron ML2 mechanism driver, cinder volume driver, keystone auth plugin,
  scheduler filter/weigher, heat resource plugin, oslo.policy rule, Tempest
  test, versioned object), or ADD an extension point. Triggers on: "what nova
  config options control live migration", "how do I configure neutron for
  VXLAN", "configure cinder with Ceph/RBD", "what Kolla-Ansible variable
  controls X", "how to enable TLS for keystone", "write a nova scheduler
  filter", "implement a neutron ML2 mechanism driver", "write a cinder volume
  driver", "add a new API to nova", "create a versioned object", "add a new
  config option", "write a Tempest test", "create a Cyborg accelerator driver".
  Always grep actual Opt() declarations and real driver implementations in the
  source — never guess at option names, defaults, or method signatures.
---

# OpenStack Build Guide — Configuration & Development

Each service has its own git repository. Clone from GitHub (mirror of OpenDev):
```bash
git clone https://github.com/openstack/<service>          --branch stable/2026.1
git clone https://github.com/openstack/ansible-collection-kolla --branch stable/2026.1
git clone https://github.com/openstack/kolla-ansible      --branch stable/2026.1
```
All path references below are relative to each repo root.

---

## Part 1 — Configuration

### Where config options are defined

Oslo.config options live in source code, not sample files:

```
<service>/<service>/conf/
  __init__.py          ← imports all groups, exposes CONF
  api.py               ← [api] group options
  compute.py           ← [compute] group options
  scheduler.py         ← [scheduler] group options
  …
```

Shared oslo.* libraries:
```
oslo.messaging/oslo_messaging/conf/     ← transport, RPC options
oslo.db/oslo_db/options.py             ← [database] connection options
oslo.log/oslo_log/log.py               ← [DEFAULT] logging options
oslo.cache/oslo_cache/core.py          ← [cache] memcached/redis options
```

### How to look up an option

```
Grep: "StrOpt\('option_name'\)|IntOpt\('option_name'\)" in conf/
Read: the file — help= is authoritative docs, default= is the real default
      (default=None or absent → must be set explicitly)
```

Group name: second arg to `conf.register_opts(opts, group='groupname')`
→ becomes `[groupname]` section in the .conf file.

### Key options by service

**Nova**
```
nova/conf/compute.py   → [compute]   vcpu_pin_set, reserved_host_memory_mb
                                     graceful_shutdown_timeout (default 180s) ← Gazpacho
                                     manager_shutdown_timeout  (default 160s) ← Gazpacho
nova/conf/scheduler.py → [scheduler] max_attempts, discover_hosts_in_cells_interval
nova/conf/libvirt.py   → [libvirt]   virt_type, cpu_mode, live_migration_scheme
                                     live_migration_parallel_connections      ← Gazpacho
nova/conf/vnc.py       → [vnc]       enabled, server_listen, novncproxy_base_url
nova/conf/quota.py     → [quota]     instances, cores, ram
```

> **2026.1 (Gazpacho)**: Nova scheduler, API, and metadata services now use **native threading by default** instead of eventlet. If you need eventlet, set `[DEFAULT] use_eventlet = true`. When upgrading, decouple the upgrade step from the concurrency-mode change to avoid unexpected behaviour.

**Neutron**
```
neutron/conf/common.py          → [DEFAULT]  core_plugin, service_plugins
neutron/plugins/ml2/config.py   → [ml2]      type_drivers, tenant_network_types
neutron/plugins/ml2/drivers/    → per-driver configs (vxlan, vlan, flat)
neutron/conf/agent/             → agent options (dhcp, l3, metadata)
```

> **2026.1 (Gazpacho)**: The **Linux Bridge ML2 driver has been removed**. Supported ML2 mechanism drivers are now **OVN** (recommended) and **Open vSwitch**. Do not configure or reference `neutron-linuxbridge-agent` in any new deployment.

**Cinder**
```
cinder/volume/configuration.py  → volume backend config
cinder/volume/drivers/rbd.py    → Ceph/RBD options (rbd_pool, rbd_user, rbd_secret_uuid)
cinder/volume/drivers/lvm.py    → LVM options (volume_group, lvm_type)
```

**Keystone**
```
keystone/conf/token.py          → [token]    provider, expiration
keystone/conf/identity.py       → [identity] driver, domain_specific_drivers_enabled
keystone/conf/ldap.py           → [ldap]     url, user_tree_dn
keystone/conf/fernet_tokens.py  → [fernet_tokens] key_repository, max_active_keys
```

**Glance**
```
glance/common/config.py         → [DEFAULT]  default_store, stores
glance/store/                   → store backends (swift, rbd, file, http)
```

---

## Part 2 — Kolla-Ansible Deployment

### Variable locations
```
ansible-collection-kolla/roles/<service>/defaults/main.yml  ← per-service defaults
ansible-collection-kolla/roles/common/defaults/main.yml     ← shared defaults
kolla-ansible/etc/kolla/globals.yml                         ← user overrides (template)
```

### Key globals.yml settings
```yaml
kolla_internal_vip_address: "10.0.0.100"  # VIP for HA control plane
network_interface: "eth0"
neutron_external_interface: "eth1"

# Enable optional services
enable_cinder: "yes"
enable_manila: "yes"
enable_octavia: "yes"
enable_magnum: "yes"
enable_designate: "yes"
enable_barbican: "yes"
enable_prometheus: "yes"
enable_opensearch: "yes"
enable_skyline: "yes"    # new in 2026.1 — Skyline modern dashboard/console
enable_valkey: "yes"     # new in 2026.1 — Valkey replaces Redis

# Backend selection
cinder_backend_ceph: "yes"
glance_backend_ceph: "yes"
```

> **2026.1 (Gazpacho) Kolla-Ansible changes:**
> - **Valkey replaces Redis** (`enable_valkey`). Data is migrated automatically during upgrade. Do not use `enable_redis` — it is removed.
> - **Skyline** is a new modern dashboard and API console (`enable_skyline`). It coexists with Horizon.
> - **Zun** (direct container service) has been **removed** from Kolla-Ansible. Use Magnum for container workloads.
> - **Swift (Kolla role)**: the Kolla-Ansible role for Swift was deprecated in 2025.2 due to broken CI and no maintainers. The Swift service itself (`opendev.org/openstack/swift`) remains active. If you deploy Swift via Kolla-Ansible, plan migration to **Ceph RGW** (which exposes a compatible S3/Swift API and has a maintained Kolla role). Standalone or manually managed Swift deployments are unaffected.
> - **2026.1 is a SLURP release** (Skip-Level-Upgrade Release), meaning it supports direct upgrade from 2025.1 (Epoxy) skipping 2025.2 (Flamingo).

### Deployment steps
```bash
pip install kolla-ansible
kolla-genpwd                                 # generate passwords
kolla-ansible install-deps
# edit /etc/kolla/globals.yml and multinode inventory
kolla-ansible bootstrap-servers -i multinode
kolla-ansible prechecks -i multinode
kolla-ansible deploy -i multinode
kolla-ansible post-deploy -i multinode
source /etc/kolla/admin-openrc.sh
```

### Control plane node roles
| Role | Services |
|---|---|
| Controller | Keystone, Nova API/Conductor/Scheduler, Neutron Server, Glance, Cinder API/Scheduler, Horizon, Skyline, Valkey, MariaDB, HAProxy, Keepalived |
| Compute | nova-compute, neutron-ovs-agent or neutron-ovn-metadata-agent (OVN) |
| Storage | cinder-volume (LVM/Ceph) |
| Network | neutron-l3-agent, neutron-dhcp-agent, neutron-metadata-agent |

---

## Part 3 — Writing Plugins & Extensions

### Extension points by service

**Nova**
| What to build | Where to look for patterns |
|---|---|
| Virt/hypervisor driver | `nova/virt/` — `libvirt/driver.py`, `fake.py` |
| Scheduler filter | `nova/scheduler/filters/` |
| Scheduler weigher | `nova/scheduler/weights/` |
| New API resource | `nova/api/openstack/compute/` |
| Versioned Object | `nova/objects/` |
| New config group | `nova/conf/` |
| Driver base class | `nova/virt/driver.py` |

**Neutron**
| What to build | Where to look |
|---|---|
| ML2 mechanism driver | `neutron/plugins/ml2/drivers/` |
| ML2 type driver | `neutron/plugins/ml2/drivers/type_*.py` |
| L3 service plugin | `neutron/services/l3_router/` |
| IPAM driver | `neutron/ipam/drivers/` |
| API extension | `neutron/extensions/` |
| Driver base class | `neutron/plugins/ml2/driver_api.py` |

**Cinder**
| What to build | Where to look |
|---|---|
| Volume driver | `cinder/volume/drivers/` — `rbd.py`, `lvm.py` |
| Scheduler filter | `cinder/scheduler/filters/` |
| Driver base class | `cinder/volume/driver.py::VolumeDriver` |

**Keystone / Heat / Cyborg / Blazar**
| What to build | Where to look |
|---|---|
| Auth plugin | `keystone/auth/plugins/` |
| Heat resource plugin | `heat/engine/resources/` |
| Cyborg accelerator driver | `cyborg/accelerators/drivers/` |
| Blazar resource plugin | `blazar/plugins/` |

### Implementation patterns

**Nova scheduler filter**
```python
from nova.scheduler import filters

class MyFilter(filters.BaseHostFilter):
    RUN_ON_REBUILD = False

    def host_passes(self, host_state, spec_obj):
        return True   # False to reject the host
```
Register in `setup.cfg` under `nova.scheduler.filters`. Add to `[filter_scheduler] enabled_filters`.

**Neutron ML2 mechanism driver**
```python
# Base class: neutron/plugins/ml2/driver_api.py::MechanismDriver
from neutron.plugins.ml2 import driver_api as api

class MyMechDriver(api.MechanismDriver):
    def initialize(self): pass

    def bind_port(self, context):
        context.set_binding(segment_id, vif_type, vif_details)
```
Register in `setup.cfg` under `neutron.ml2.mechanism_drivers`.

**Cinder volume driver**
```python
# Base class: cinder/volume/driver.py::VolumeDriver
# Required methods: create_volume, delete_volume, create_snapshot,
#   delete_snapshot, initialize_connection, terminate_connection
# Capabilities: self._stats dict with volume_backend_name, storage_protocol
```
Register in `setup.cfg` under `cinder.volume.drivers`.

**New oslo.config option**
```python
# In <service>/conf/mygroup.py
from oslo_config import cfg

MY_OPTS = [
    cfg.StrOpt('my_option', default='val', help='Description.'),
    cfg.IntOpt('my_count', default=10, min=1),
]

def register_opts(conf):
    conf.register_opts(MY_OPTS, group='my_group')

def list_opts():
    return {'my_group': MY_OPTS}
```
Import and call `register_opts(CONF)` in `<service>/conf/__init__.py`.

**Versioned Object (OVO)**
```python
from oslo_versionedobjects import base, fields

@base.VersionedObjectRegistry.register
class MyObject(base.VersionedObject, base.VersionedObjectDictCompat):
    VERSION = '1.0'
    fields = {
        'id': fields.UUIDField(),
        'name': fields.StringField(),
    }

    @base.remotable_classmethod
    def get_by_id(cls, context, obj_id):
        db_obj = db.my_object_get(context, obj_id)
        return cls._from_db_object(context, cls(), db_obj)
```

**Tempest test**
```python
from tempest.api.compute import base
from tempest.lib import decorators

class MyServerTest(base.BaseV2ComputeTest):
    @decorators.idempotent_id('unique-uuid-here')
    def test_my_feature(self):
        server = self.create_test_server(wait_until='ACTIVE')
        # assert something
```

---

## Response format

**For configuration questions:**
1. Option name and section: `[libvirt] virt_type = kvm`
2. Type and default (from `Opt()` constructor — always verify in source)
3. `help=` string verbatim
4. File path + Grep result
5. Kolla-Ansible equivalent if applicable
6. Minimal working snippet (only options that differ from defaults)

**For development questions:**
1. Base class / interface to implement (file + class name from source)
2. Minimal working skeleton with correct method signatures
3. Real example from codebase (2-3 existing implementations)
4. `setup.cfg` entry_point or conf option to enable it
5. Where to put the test and what base class to use

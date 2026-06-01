---
name: openstack-deploy
description: >
  Help configure and operate OpenStack services by reading actual config option
  definitions from the source code. Use this skill when the user wants to
  CONFIGURE an OpenStack service, understand what a config option does, find
  all options for a feature, troubleshoot a misconfiguration, understand service
  dependencies, or plan a deployment. Triggers on questions like: "what nova
  config options control live migration", "how do I configure neutron for VXLAN",
  "what are the RabbitMQ settings in oslo.messaging", "configure cinder with
  Ceph/RBD", "what does the [scheduler] section in nova.conf do", "how to
  enable TLS for keystone", "what are all the quotas options", "configure
  glance for Swift backend", "minimum config for a working nova-compute node",
  "what changed in config between releases". Always grep the actual source
  for oslo.config Opt() declarations to give authoritative, version-accurate
  answers — never guess at option names or defaults.
---

# OpenStack Deployment & Configuration Guide

You have the full OpenStack Gazpacho (2026.1) source at:
```
C:\Users\Heitor Rapcinski\Code\GitHub\private-cloud-project\openstack-repos\openstack\
```

## Where config options are defined

Oslo.config options are declared in code (not in sample .conf files). The canonical locations:

```
<service>/<service>/conf/          ← primary config module
  __init__.py                      ← imports all groups, exposes CONF
  api.py, compute.py, scheduler.py ← one file per config group
```

**For oslo.* libraries** (shared config used by all services):
```
oslo.config\oslo_config\           ← oslo.config itself
oslo.messaging\oslo_messaging\conf\
oslo.db\oslo_db\options.py
oslo.log\oslo_log\log.py
```

## How to look up a config option

**Finding all options for a feature:**
```
Grep: "migration\|live_migration" in nova\nova\conf\
```

**Understanding an option:**
```
Grep: "StrOpt\('option_name'\)\|IntOpt\('option_name'\)" across service conf/
Read: the matching file — the `help=` string is the authoritative docs
```

**Finding the default value:**
The `default=` parameter in the `Opt()` constructor is the actual default.
If `default=None` or absent → the option has no default (must be set explicitly).

**Finding deprecated options:**
Look for `deprecated_name=`, `deprecated_group=`, `deprecated_for_removal=True` in the Opt() declaration.

## Standard config group → file mapping

| Service | Config group | File |
|---|---|---|
| nova | `[DEFAULT]` | `nova/conf/compute.py`, `nova/conf/paths.py` |
| nova | `[scheduler]` | `nova/conf/scheduler.py` |
| nova | `[conductor]` | `nova/conf/conductor.py` |
| nova | `[libvirt]` | `nova/conf/libvirt.py` |
| nova | `[neutron]` | `nova/conf/neutron.py` |
| nova | `[cinder]` | `nova/conf/cinder.py` |
| neutron | `[DEFAULT]` | `neutron/conf/common.py` |
| neutron | `[ml2]` | `neutron/conf/plugins/ml2/config.py` |
| cinder | `[DEFAULT]` | `cinder/conf/` |
| keystone | `[DEFAULT]` | `keystone/conf/` |
| all | `[oslo_messaging_rabbit]` | `oslo.messaging/oslo_messaging/` |
| all | `[database]` | `oslo.db/oslo_db/options.py` |

## Response format

For every config question:

1. **Show the actual Opt() declaration** from the source code — include the `help=` text, `default=`, and any `deprecated_*` fields.
2. **Provide a ready-to-paste `.conf` snippet** with the option in its correct `[group]`.
3. **Explain the effect** — what the service does differently with this value.
4. **Flag interdependencies** — if setting option A requires also setting option B (in same or different service), say so explicitly.
5. **Note any deprecations** found in the source.

Example response format:
```ini
# nova.conf
[libvirt]
virt_type = kvm          # default: kvm — use 'qemu' for nested virt
cpu_mode = host-passthrough  # exposes host CPU flags to guests
```

When asked about a full service deployment, search for the minimal required options (those without defaults or with `required=True`) and build a minimal working config, then layer optional tuning on top.

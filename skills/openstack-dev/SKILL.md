---
name: openstack-dev
description: >
  Development guidance for writing OpenStack plugins, drivers, and extensions
  using real patterns from the local source code. Use this skill when the user
  wants to CREATE or EXTEND OpenStack functionality: writing a nova virt driver,
  a neutron ML2 mechanism driver, a cinder volume driver, a keystone auth
  plugin, a scheduler filter/weigher, a heat resource plugin, an oslo.policy
  rule, a Tempest test, or any other OpenStack extension point. Also triggers
  for questions like "how do I add a new API to nova", "implement a custom
  scheduler filter", "write a notification listener", "create a new oslo
  versioned object", "add a new config option", "write a functional test for
  neutron". Always look at existing implementations in the local codebase to
  show real, idiomatic patterns rather than made-up examples.
---

# OpenStack Developer Guide

You have the full OpenStack Gazpacho (2026.1) source at:
```
C:\Users\Heitor Rapcinski\Code\GitHub\private-cloud-project\openstack-repos\openstack\
```

## Extension points — where to look for real patterns

### Nova
| What to build | Where to look |
|---|---|
| Virt/hypervisor driver | `nova\virt\` — e.g., `libvirt\driver.py`, `fake.py` |
| Scheduler filter | `nova\scheduler\filters\` |
| Scheduler weigher | `nova\scheduler\weights\` |
| API extension | `nova\api\openstack\compute\` |
| RPC API | `nova\conductor\rpcapi.py`, `nova\compute\rpcapi.py` |
| New OVO (versioned object) | `nova\objects\` |
| New config group | `nova\conf\` |

### Neutron
| What to build | Where to look |
|---|---|
| ML2 mechanism driver | `neutron\plugins\ml2\drivers\` |
| ML2 type driver | `neutron\plugins\ml2\drivers\` — `type_vlan.py`, `type_vxlan.py` |
| Service plugin | `neutron\services\` |
| Agent extension | `neutron\agent\` |
| API extension | `neutron\extensions\` |

### Cinder
| What to build | Where to look |
|---|---|
| Volume driver | `cinder\volume\drivers\` — e.g., `lvm.py`, `rbd.py` |
| Scheduler filter | `cinder\scheduler\filters\` |
| API extension | `cinder\api\contrib\` |

### Keystone
| What to build | Where to look |
|---|---|
| Auth plugin | `keystone\auth\plugins\` |
| Backend driver | `keystone\identity\backends\` |
| Policy | `keystone\common\policies\` |

### Cross-cutting
| What to build | Where to look |
|---|---|
| oslo.config group | Any `<service>/conf/<group>.py` |
| oslo.policy rule | Any `<service>/common/policies/` or `<service>/policies/` |
| Versioned object | Any `<service>/objects/<resource>.py` |
| Tempest test | `<service>-tempest-plugin\` repos |
| Notification | `nova\notifications\` or grep for `rpc.notify` |

## Workflow for each task

1. **Find the base class / interface** — Grep for `class Base`, `ABC`, `abstractmethod` in the relevant subsystem. Read it to understand the contract.
2. **Find a concrete example** — Pick a simple existing implementation (e.g., `FakeDriver`, `SimpleCIDRAllocationPool`). Read it to see the real pattern.
3. **Show the scaffolding** — Write the new class implementing the same interface, filled with real method signatures from the base class.
4. **Show registration** — Most plugins are registered via `entry_points` in `setup.cfg`, or via `CONF` option. Find how existing drivers register themselves and replicate it.
5. **Show the test pattern** — Find the corresponding test file (mirror path under `tests/`) and show how existing tests mock dependencies.

## Code quality standards in OpenStack

- Use `oslo.log` for logging (not stdlib `logging` directly)
- Config options go in `<service>/conf/<group>.py`, imported in `<service>/conf/__init__.py`
- Exceptions go in `<service>/exception.py`, inheriting from existing base exceptions
- DB access only via objects layer (Oslo Versioned Objects), not raw SQLAlchemy
- Unit tests in `tests/unit/`, functional in `tests/functional/`
- Follow `hacking` rules (check `<service>/hacking/checks.py`)

Always show actual code from the repo, not invented examples.

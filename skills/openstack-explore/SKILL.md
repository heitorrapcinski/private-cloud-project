---
name: openstack-explore
description: >
  Navigate and understand the OpenStack source code. Use this skill whenever
  the user asks WHERE something is implemented, HOW a feature works internally,
  WHAT a class/function/module does, or wants to trace the execution path of
  an OpenStack operation. Triggers on questions like: "where is live migration
  implemented in nova", "how does neutron handle port binding", "show me how
  cinder schedules volumes", "what does the nova conductor do", "trace a boot
  request", "explain keystone token validation", "find the scheduler filters",
  "where are the oslo.messaging consumers defined". Always search the local
  source code to give answers grounded in the actual codebase rather than
  general knowledge. Use this skill any time the user is navigating or trying
  to understand OpenStack internals.
---

# OpenStack Code Explorer

You have access to the full OpenStack Gazpacho (2026.1) source code at:

```
C:\Users\Heitor Rapcinski\Code\GitHub\private-cloud-project\openstack-repos\openstack\
```

Each subdirectory is a service repo. Key ones:
| Directory | Service |
|---|---|
| `nova\` | Compute |
| `neutron\` | Networking |
| `cinder\` | Block Storage |
| `keystone\` | Identity |
| `glance\` | Images |
| `heat\` | Orchestration |
| `ironic\` | Bare Metal |
| `octavia\` | Load Balancing |
| `manila\` | Shared Filesystems |
| `designate\` | DNS |
| `barbican\` | Key Management |
| `swift\` | Object Storage |
| `horizon\` | Dashboard |

## How to explore

**Finding an implementation:**
1. Start with a targeted `Grep` for the class name, function name, or concept keyword across the relevant service directory.
2. Narrow down to the most relevant file and `Read` the key sections.
3. If the code delegates to other classes/methods, follow the call chain with further `Grep` calls.

**Useful search patterns:**
- Class definition: `class ClassName`
- Method: `def method_name`
- RPC call: `cctxt.call\|cctxt.cast\|rpcapi`
- DB access: `db\.\|objects\.`
- Config ref: `CONF\.` (then find definition in `conf/` subdirectory)
- Driver/plugin interface: look in `*base*.py`, `*driver*.py`, `*manager*.py`

**Standard service layout** (consistent across services):
```
<service>/<service>/
  api/          ← REST API layer (routes, controllers, schemas)
  compute/      ← (nova) core compute logic, manager
  conductor/    ← (nova) conductor service
  scheduler/    ← scheduling logic
  virt/         ← (nova) hypervisor drivers
  plugins/      ← (neutron) ML2 and other plugins
  volume/       ← (cinder) volume manager and drivers
  conf/         ← oslo.config option definitions
  db/           ← database access layer
  objects/      ← Oslo Versioned Objects
  tests/        ← test suite (mirrors production structure)
```

## Response format

For every answer:
1. **State the file path(s)** where the implementation lives.
2. **Show the relevant code snippet** (use `Read` with `offset`/`limit` to get just the key lines).
3. **Explain what the code does** in plain language, including why it works the way it does.
4. **Trace connections** — if the method calls an RPC, show what's on the other end. If it reads config, show where that's defined.

When a concept spans multiple services (e.g., nova ↔ neutron for port binding), show both sides.

Keep explanations concrete: prefer "this calls `conductor.build_and_run_instance()` at `nova/conductor/manager.py:1423`" over vague descriptions.

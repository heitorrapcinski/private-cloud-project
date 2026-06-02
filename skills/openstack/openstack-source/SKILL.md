---
name: openstack-source
description: >
  Read, navigate, and explain OpenStack source code — covering both internal
  implementation and the REST API surface. Use this skill for any question
  that requires looking at the actual code: WHERE is something implemented,
  HOW does a feature work internally, WHAT does a class/function/module do,
  WHAT is the exact API endpoint to call, WHAT request body does it expect,
  WHAT policy rule governs an operation, WHAT microversion introduced a field,
  or HOW to interpret an API error. Triggers on: "where is live migration
  implemented in nova", "how does neutron handle port binding", "trace a boot
  request", "what's the API to resize an instance", "show me the neutron
  create port request body", "what fields does GET /servers/{id} return",
  "what policy rule controls cinder volume deletion", "when was the tags API
  added to nova", "generate a curl command for creating a Cinder volume",
  "how does placement compute allocation candidates", "what does HTTP 409 mean
  in this context", "trace a neutron router creation", "how does Masakari
  detect instance failures", "explain keystone token validation". Always read
  real code — never invent field names, policy rules, or method signatures.
---

# OpenStack Source Explorer

Each service has its own git repository. Browse or clone from GitHub (mirror of OpenDev):
```
https://github.com/openstack/<service>   branch: stable/2026.1
https://opendev.org/openstack/<service>  (canonical)
```
All path references below are relative to each service repo root.

## Service repository map

| Repo | Service |
|---|---|
| `nova` | Compute |
| `neutron` | Networking |
| `cinder` | Block Storage |
| `keystone` | Identity |
| `glance` | Images |
| `heat` | Orchestration |
| `ironic` | Bare Metal |
| `octavia` | Load Balancing |
| `manila` | Shared Filesystems |
| `designate` | DNS |
| `barbican` | Key Management |
| `swift` | Object Storage |
| `horizon` | Dashboard |
| `masakari` | Instance HA / Failover |
| `watcher` | Resource Optimization |
| `blazar` | Resource Reservation |
| `cyborg` | Accelerator Framework |
| `magnum` | Container Orchestration (Kubernetes) |
| `aodh` | Alerting |
| `ceilometer` | Telemetry |

## Standard service layout

```
<service>/<service>/
  api/          ← REST API (routes, controllers, schemas, policies)
  conf/         ← oslo.config option definitions
  db/           ← database access layer + models
  objects/      ← Oslo Versioned Objects (OVO)
  notifications/← notification payload objects
  scheduler/    ← scheduling logic
  tests/        ← test suite (mirrors production structure)
  cmd/          ← entry points (nova-api, nova-compute, etc.)
```

## Finding API definitions

### Nova (Compute)
```
nova/nova/api/openstack/compute/
  schemas/          ← JSON Schema for every request body
  routes.py         ← URL → controller mapping
  *.py              ← one controller per resource (servers.py, flavors.py…)
nova/nova/policies/                              ← oslo.policy rules
nova/nova/api/openstack/compute/microversions.py ← microversion history
nova/nova/api/openstack/placement/              ← Placement API
nova/nova/api/openstack/placement/schemas/
```

### Neutron (Networking)
```
neutron/neutron/api/v2/        ← core APIv2 router
neutron/neutron/extensions/    ← one file per extension (adds fields/resources)
neutron/neutron/db/models/     ← persisted field names
neutron/neutron/policies/      ← policy rules
```

### Cinder (Block Storage)
```
cinder/cinder/api/v3/          ← v3 controllers
cinder/cinder/api/schemas/     ← request schemas
cinder/cinder/policies/        ← policy rules
```

### Keystone (Identity)
```
keystone/keystone/server/controllers/  ← controllers
keystone/keystone/common/policies/     ← policy rules
```

### Glance (Image)
```
glance/glance/api/v2/                  ← v2 controllers
glance/glance/api/property_protections.py
```

### Manila (Shared Filesystems)
```
manila/manila/api/v2/          ← v2 controllers
manila/manila/api/schemas/     ← request/response schemas
manila/manila/policies/        ← policy rules
```

### Octavia (Load Balancer)
```
octavia/octavia/api/v2/controllers/  ← resource controllers
octavia/octavia/api/v2/types/        ← request/response type definitions
octavia/octavia/policies/            ← policy rules
```

### Ironic (Bare Metal)
```
ironic/ironic/api/controllers/v1/  ← v1 controllers (nodes, ports, chassis)
ironic/ironic/api/types.py         ← field type definitions
ironic/ironic/policies/            ← policy rules
```

## How to search the source

**Endpoint by URL:**
```
Grep: "'/servers'" or resource name in routes.py / wsgi.py
```

**Request/response fields:**
```
Grep: resource name in schemas/
Read: the schema file — 'properties' = all fields, 'required' = mandatory ones
```

**Policy rule:**
```
Grep: action name (e.g., "compute:servers:create") in policies/
```

**Microversion changes (Nova):**
```
Grep: "microversion|min_ver|max_ver" in the controller
Grep: feature name in nova/api/openstack/compute/microversions.py
```

**Internal implementation:**
```
Class definition  → Grep: "class ClassName"
Method            → Grep: "def method_name"
RPC call          → Grep: "cctxt.call|cctxt.cast|rpcapi"
DB access         → Grep: "db\.|objects\."
Config ref        → Grep: "CONF\." (then find definition in conf/ subdir)
Driver interface  → look in *base*.py, *driver*.py, *manager*.py
```

## Key execution paths

### Nova: instance boot
```
api/compute/servers.py::ServersController.create()
  → compute/api.py::API.create()
  → conductor/rpcapi.py::ComputeTaskAPI.build_instances()
  → conductor/manager.py::ComputeTaskManager.build_and_run_instance()
  → scheduler → compute/rpcapi.py → compute/manager.py::_do_build_and_run_instance()
  → virt/<driver>/driver.py::spawn()
```

### Neutron: port binding (ML2)
```
plugins/ml2/plugin.py::Ml2Plugin.update_port()
  → plugins/ml2/managers.py::MechanismManager.bind_port()
  → <mechanism_driver>.bind_port(context)
```

### Cinder: volume create
```
api/v3/volumes.py → volume/api.py → scheduler/rpcapi.py
  → scheduler/manager.py → <filter_scheduler>
  → volume/rpcapi.py → volume/manager.py → <volume_driver>.create_volume()
```

### Keystone: token validation
```
(keystonemiddleware) auth_token.py
  → keystone/server/controllers/auth.py::Auth.validate_token()
  → keystone/token/providers/fernet/provider.py::Provider.validate_token()
```

### Placement: allocation candidates
```
nova/api/openstack/placement/handlers/allocation_candidate.py
  → objects/allocation_candidate.py::AllocationCandidates.get_by_requests()
  → SQL on resource_providers, inventories, allocations tables
```

## API response format

For every API question:

1. **Method + URL** — e.g., `POST /v2.1/{project_id}/servers`
2. **Required microversion** (if any) — e.g., `X-OpenStack-Nova-Microversion: 2.74`
3. **Request body** — fields, types, required vs optional (from schema)
4. **Response** — key fields returned (from schema or controller)
5. **Policy rule** — which rule governs the call and its default
6. **Example curl**:
```bash
curl -X POST https://nova:8774/v2.1/{project_id}/servers \
  -H "X-Auth-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"server": {"name": "vm", "flavorRef": "1", "imageRef": "uuid"}}'
```

## Code exploration response format

1. **File path(s)** where the implementation lives.
2. **Relevant code snippet** — use offset/limit to get just the key lines.
3. **Plain-language explanation** of what it does and why.
4. **Call chain** — if the method delegates via RPC, show the other end.

When a concept spans services (e.g., nova ↔ neutron for port binding), show both sides. Prefer "this calls `conductor.build_and_run_instance()` at `conductor/manager.py:1423`" over vague descriptions.

## Common gotchas

- **Nova microversions**: max version in 2026.1 is **2.103**. Without the header the server responds at the base version. Always check `microversions.py` for the version that introduced a field. Highlight: 2.101 makes `POST /servers/{id}/os-volume_attachments` async (returns HTTP 202 instead of 200).
- **Neutron extensions**: many fields come from extensions in `neutron/extensions/`, not the base API.
- **Neutron Linuxbridge**: the Linux Bridge ML2 driver was **removed in 2026.1**. OVN is now the primary ML2 driver alongside Open vSwitch. Do not reference Linuxbridge in any deployment guidance.
- **Policy scope**: since Bobcat (2023.1) many services use `scope_type = ['project', 'system']` — check both the rule and `scope_types` attribute.
- **Cinder v2**: removed in 2026.1; all calls use v3.
- **Placement**: uses resource classes (`VCPU`, `MEMORY_MB`, `DISK_GB`) and traits (`HW_CPU_X86_VMX`), not server-style JSON bodies.
- **Zun**: removed from OpenStack 2026.1. Direct container service is no longer available; use Magnum for Kubernetes-managed containers.

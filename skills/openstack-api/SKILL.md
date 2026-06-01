---
name: openstack-api
description: >
  Explore and explain OpenStack REST APIs directly from the source code — routes,
  request/response schemas, policy rules, and microversion history. Use this
  skill when the user asks about OpenStack API endpoints: what URL to call, what
  request body to send, what fields are returned, what policy governs access,
  what microversion introduced a feature, or how to interpret an API error.
  Triggers on: "what's the API to resize a nova instance", "show me the
  neutron create port request body", "what fields does GET /servers/{id} return",
  "what policy rule controls cinder volume deletion", "when was the tags API
  added to nova", "how do I call the placement API for resource providers",
  "list all nova microversions", "what does HTTP 409 mean in this context",
  "generate a curl command for creating a Cinder volume", "what changed in
  nova API microversion 2.96". Always read the actual route definitions,
  JSON schemas, and policy files from the local source — never invent field
  names or policy rules.
---

# OpenStack API Explorer

You have the full OpenStack Gazpacho (2026.1) source at:
```
C:\Users\Heitor Rapcinski\Code\GitHub\private-cloud-project\openstack-repos\openstack\
```

## Where API definitions live

### Nova (Compute API)
```
nova\nova\api\openstack\compute\
  schemas\          ← JSON Schema for every request body (Python dicts)
  *.py              ← one controller per resource (servers.py, flavors.py…)
nova\nova\api\openstack\compute\routes.py   ← URL → controller mapping
nova\nova\policies\                         ← oslo.policy rules per resource
nova\nova\api\openstack\compute\microversions.py  ← microversion history
```

### Neutron (Networking API)
```
neutron\neutron\api\v2\        ← core APIv2 router
neutron\neutron\extensions\    ← one file per API extension (resource)
neutron\neutron\db\models\     ← what gets persisted (field names)
neutron\neutron\policies\      ← policy rules
```

### Cinder (Block Storage API)
```
cinder\cinder\api\v3\          ← v3 controllers
cinder\cinder\api\schemas\     ← request schemas
cinder\cinder\policies\        ← policy rules
```

### Keystone (Identity API)
```
keystone\keystone\server\controllers\  ← controllers
keystone\keystone\common\policies\     ← policy rules
```

### Glance (Image API)
```
glance\glance\api\v2\          ← v2 controllers
glance\glance\api\property_protections.py
```

### Placement
```
nova\nova\api\openstack\placement\   ← placement API (co-located with nova)
nova\nova\api\openstack\placement\schemas\
```

## How to explore an API endpoint

**Finding an endpoint by URL:**
```
Grep: "'/servers'" or the resource name in routes.py or wsgi.py
```

**Finding request/response fields:**
```
Grep: the resource name in schemas/ directory
Read: the schema file — 'properties' lists all fields, 'required' shows mandatory ones
```

**Finding policy rules:**
```
Grep: the action name (e.g., "compute:servers:create") in policies/
Read: the policy file — shows default rule and description
```

**Finding microversion changes:**
```
Grep: "microversion\|min_ver\|max_ver\|@wsgi.expected_errors" in the controller
Grep: the feature name in nova/api/openstack/compute/microversions.py
```

## Response format

For every API question:

1. **Method + URL**: `POST /v2.1/{project_id}/servers`
2. **Required microversion** (if any): `X-OpenStack-Nova-Microversion: 2.74`
3. **Request body** (from schema): show all fields with types, which are required, and valid values.
4. **Response** (from schema or controller): key fields returned.
5. **Policy rule**: which rule governs this call and its default (from policy file).
6. **Example curl**:
```bash
curl -X POST https://nova:8774/v2.1/{project_id}/servers \
  -H "X-Auth-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"server": {"name": "my-vm", "flavorRef": "1", "imageRef": "uuid"}}'
```

Show the actual schema Python dict when it helps clarify field names and constraints — this is more authoritative than documentation.

When the user asks about an error code (e.g., 409 Conflict), grep for where that HTTP status is raised in the controller to explain the exact condition.

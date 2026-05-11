# 06 - Design de Segurança

## Princípios Zero Trust

```
┌─────────────────────────────────────────────────────────────────┐
│                    Security Architecture                          │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Layer 1: Network Segmentation (VLANs, ACLs, OVN SG)   │    │
│  ├─────────────────────────────────────────────────────────┤    │
│  │  Layer 2: Identity & Access (Keystone, RBAC, Federation)│    │
│  ├─────────────────────────────────────────────────────────┤    │
│  │  Layer 3: Encryption (TLS everywhere, Barbican KMS)     │    │
│  ├─────────────────────────────────────────────────────────┤    │
│  │  Layer 4: Secrets Management (Barbican, Vault)          │    │
│  ├─────────────────────────────────────────────────────────┤    │
│  │  Layer 5: Audit & Compliance (oslo.policy, CADF)        │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## TLS Everywhere

### Certificate Architecture

```
┌──────────────────────────────────────────────────┐
│              PKI Hierarchy                         │
│                                                    │
│  Root CA (offline, HSM-backed)                    │
│  ├── Intermediate CA - Infrastructure             │
│  │   ├── HAProxy (API endpoints)                  │
│  │   ├── MariaDB (Galera SSL)                     │
│  │   ├── RabbitMQ (AMQPS)                         │
│  │   └── Internal services (mTLS)                 │
│  ├── Intermediate CA - Tenant                     │
│  │   ├── Octavia LB certificates                  │
│  │   └── Barbican-managed certs                   │
│  └── Intermediate CA - Management                 │
│      ├── BMC/IPMI                                 │
│      └── Switch management                        │
└──────────────────────────────────────────────────┘
```

### HAProxy TLS Termination

```ini
# /etc/haproxy/haproxy.cfg (frontend)
frontend openstack_api
    bind 10.0.10.5:443 ssl crt /etc/haproxy/certs/api.pem alpn h2,http/1.1
    bind 10.0.10.5:5000 ssl crt /etc/haproxy/certs/api.pem
    http-request set-header X-Forwarded-Proto https
    http-request set-header X-SSL-Client-Verify %[ssl_fc_has_crt]
    
    # HSTS
    http-response set-header Strict-Transport-Security "max-age=31536000; includeSubDomains"
    
    # Security headers
    http-response set-header X-Content-Type-Options nosniff
    http-response set-header X-Frame-Options DENY
```

### Inter-Service mTLS

```ini
# Cada serviço OpenStack
[ssl]
ca_file = /etc/pki/ca-trust/source/anchors/openstack-ca.pem
cert_file = /etc/pki/tls/certs/service.pem
key_file = /etc/pki/tls/private/service.key

[oslo_messaging_rabbit]
ssl = true
ssl_ca_file = /etc/pki/ca-trust/source/anchors/openstack-ca.pem
ssl_cert_file = /etc/pki/tls/certs/service.pem
ssl_key_file = /etc/pki/tls/private/service.key

[database]
connection = mysql+pymysql://nova:PASS@10.0.200.5/nova?ssl_ca=/etc/pki/ca-trust/source/anchors/galera-ca.pem
```

## Barbican (Key Management Service)

### Arquitetura

```
┌──────────────────────────────────────────────────┐
│              Barbican Architecture                 │
│                                                    │
│  barbican-api (3x) → barbican-worker (3x)        │
│                           │                        │
│                    ┌──────┴──────┐                │
│                    │  PKCS#11    │                │
│                    │  Crypto     │                │
│                    └──────┬──────┘                │
│                           │                        │
│              ┌────────────┼────────────┐          │
│              │            │            │          │
│         ┌────┴───┐  ┌────┴───┐  ┌────┴───┐     │
│         │ HSM-01 │  │ HSM-02 │  │ HSM-03 │     │
│         │ (AZ1)  │  │ (AZ2)  │  │ (AZ3)  │     │
│         │ FIPS L3│  │ FIPS L3│  │ FIPS L3│     │
│         └────────┘  └────────┘  └────────┘     │
│                                                    │
│  FIPS 140-2 Level 3 | HA Group (Active-Active)   │
│  Ver: docs/10-hsm-key-management.md              │
└──────────────────────────────────────────────────┘
```

### Configuração

```ini
# /etc/barbican/barbican.conf
[DEFAULT]
sql_connection = mysql+pymysql://barbican:PASS@10.0.200.5/barbican

[secretstore]
enabled_secretstore_plugins = store_crypto

[crypto]
enabled_crypto_plugins = p11_crypto

[p11_crypto_plugin]
library_path = /usr/lib/libCryptoki2_64.so
slot_id = 1
login = PARTITION_PASSWORD
mkek_label = barbican-mkek
mkek_length = 32
hmac_label = barbican-hmac
encryption_mechanism = CKM_AES_CBC_PAD
token_label = barbican-ha

[certificate]
enabled_certificate_plugins = snakeoil_ca
```

### Integração com Serviços

| Serviço | Uso do Barbican |
|---------|-----------------|
| Nova | Encrypted volumes (dm-crypt keys) |
| Cinder | Volume encryption keys |
| Octavia | TLS certificates para LBs |
| Swift | Encryption-at-rest keys |
| Glance | Encrypted image signatures |
| Neutron | VPN pre-shared keys |

## Keystone Federation (SAML2/OIDC)

### Arquitetura

```
┌──────────────────────────────────────────────────┐
│           Identity Federation                     │
│                                                    │
│  ┌──────────┐     ┌──────────┐                   │
│  │Corporate │     │ Keystone │                   │
│  │   IdP    │────►│   (SP)   │                   │
│  │(AD/ADFS) │SAML │          │                   │
│  └──────────┘     └────┬─────┘                   │
│                         │                          │
│                    ┌────┴─────┐                   │
│                    │ Mapping  │                   │
│                    │  Rules   │                   │
│                    └────┬─────┘                   │
│                         │                          │
│              ┌──────────┴──────────┐              │
│              │  OpenStack Projects │              │
│              │  & Roles            │              │
│              └─────────────────────┘              │
└──────────────────────────────────────────────────┘
```

### Federation Configuration

```ini
# /etc/keystone/keystone.conf
[federation]
trusted_dashboard = https://horizon.cloud.internal/auth/websso/
sso_callback_template = /etc/keystone/sso_callback_template.html

[auth]
methods = password,token,mapped,openid

[openid]
remote_id_attribute = HTTP_OIDC_ISS
```

### Mapping Rules

```json
[
  {
    "local": [
      {
        "user": {"name": "{0}"},
        "group": {"id": "cloud-admins-group-id"}
      }
    ],
    "remote": [
      {"type": "HTTP_OIDC_SUB"},
      {"type": "HTTP_OIDC_GROUPS", "any_one_of": ["cloud-admins"]}
    ]
  },
  {
    "local": [
      {
        "user": {"name": "{0}"},
        "group": {"id": "cloud-users-group-id"}
      }
    ],
    "remote": [
      {"type": "HTTP_OIDC_SUB"},
      {"type": "HTTP_OIDC_GROUPS", "any_one_of": ["cloud-users"]}
    ]
  }
]
```

## RBAC (Role-Based Access Control)

### Project Structure

```
Domain: cloud.internal
├── Project: admin (cloud operators)
├── Project: service (OpenStack services)
├── Project: infrastructure (shared resources)
└── Domain: tenants
    ├── Project: tenant-a
    ├── Project: tenant-b
    └── Project: tenant-c
```

### Custom Roles

| Role | Scope | Permissions |
|------|-------|-------------|
| cloud_admin | Domain | Full access all services |
| project_admin | Project | Full access within project |
| compute_user | Project | Create/manage VMs |
| network_admin | Project | Create/manage networks |
| storage_user | Project | Create/manage volumes |
| readonly | Project | List/show only |
| auditor | Domain | Read-only all projects |

### Policy Customization

```yaml
# /etc/nova/policy.yaml
"os_compute_api:servers:create": "role:compute_user or role:project_admin"
"os_compute_api:servers:delete": "role:compute_user or role:project_admin"
"os_compute_api:servers:create:forced_host": "role:cloud_admin"
"os_compute_api:os-migrate-server:migrate_live": "role:cloud_admin"
```

## Network Security

### Security Groups (OVN)

```bash
# Default deny-all ingress
openstack security group rule create --ingress --protocol tcp --dst-port 22 --remote-ip 10.0.0.0/8 default
openstack security group rule create --ingress --protocol icmp default
# Egress permitido por default
```

### Network Isolation

| Rede | Acesso Permitido | Bloqueado |
|------|-------------------|-----------|
| Management (VLAN 10) | Controllers, admins | Tenants, internet |
| Storage (VLAN 20) | Compute, storage nodes | Tenants, internet |
| Tenant (VXLAN) | Apenas mesmo tenant | Cross-tenant |
| External (VLAN 40) | Floating IPs | Direct access |
| DB Replication (VLAN 200) | DB/MQ nodes only | Tudo mais |

### Firewall Rules (Host-level)

```bash
# /etc/nftables.conf (controller nodes)
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        iif lo accept
        # Management
        ip saddr 10.0.10.0/24 tcp dport {22, 5000, 8774, 9696, 9292, 8776} accept
        # Internal API
        ip saddr 10.0.100.0/24 accept
        # DB Replication
        ip saddr 10.0.200.0/24 tcp dport {3306, 4567, 4568, 4444} accept
        # RabbitMQ
        ip saddr 10.0.200.0/24 tcp dport {5672, 25672, 4369} accept
        # Monitoring
        ip saddr 10.0.10.0/24 tcp dport {9100, 9090} accept
        log prefix "DROPPED: " drop
    }
}
```

## Encryption at Rest

### Cinder Volume Encryption

```ini
# /etc/cinder/cinder.conf
[key_manager]
backend = barbican

# Create encrypted volume type
# openstack volume type create encrypted-luks
# openstack volume type set encrypted-luks --encryption-provider luks \
#   --encryption-cipher aes-xts-plain64 --encryption-key-size 256 \
#   --encryption-control-location front-end
```

### Swift Encryption

```ini
# /etc/swift/proxy-server.conf (encryption middleware)
[filter:encryption]
use = egg:swift#encryption

[filter:keymaster]
use = egg:swift#keymaster
encryption_root_secret = BARBICAN_SECRET_REF
```

## Audit & Compliance

### CADF Notifications

```ini
# Todos os serviços
[oslo_messaging_notifications]
driver = messagingv2
transport_url = rabbit://openstack:PASS@mq-01:5672,mq-02:5672,mq-03:5672/
topics = notifications

[audit_middleware_notifications]
driver = log
```

### Audit Events Captured

- Authentication success/failure
- Resource creation/deletion
- Policy violations
- Admin actions
- Configuration changes

## Hardening Checklist

- [ ] Disable root SSH login
- [ ] SSH key-only authentication
- [ ] Fail2ban on all nodes
- [ ] Automatic security updates (unattended-upgrades)
- [ ] CIS Benchmark compliance (Ubuntu 24.04)
- [ ] SELinux/AppArmor enforcing
- [ ] Disable unnecessary services
- [ ] NTP synchronized (chrony)
- [ ] Log forwarding to central SIEM
- [ ] Regular vulnerability scanning
- [ ] Secrets rotation (90 days)
- [ ] Certificate rotation (365 days)
- [ ] Database encryption at rest
- [ ] Backup encryption

## Decisões Arquiteturais

1. **TLS Everywhere**: Zero trust entre serviços, mesmo em rede interna
2. **Barbican + HSM (PKCS#11)**: Chaves mestras protegidas por hardware FIPS 140-2 Level 3, cluster HA 3 AZs
3. **OIDC Federation**: SSO com corporate IdP, sem password sync
4. **Fernet tokens**: Sem token persistence, reduz attack surface
5. **OVN Security Groups**: Distributed firewall, sem bottleneck central
6. **nftables**: Modern replacement para iptables, melhor performance
7. **LUKS volume encryption**: Transparent para VMs, keys em Barbican

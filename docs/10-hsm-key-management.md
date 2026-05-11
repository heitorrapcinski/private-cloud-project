# 11 - HSM Key Management (Gestão de Chaves Criptográficas)

## Visão Geral

```
┌─────────────────────────────────────────────────────────────────┐
│              HSM Cluster — FIPS 140-2 Level 3                    │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Barbican API (3x, stateless)                │    │
│  │              Plugin: PKCS#11 Crypto                       │    │
│  └────────────────────────┬────────────────────────────────┘    │
│                           │                                      │
│       ┌───────────────────┼───────────────────┐                 │
│       │                   │                   │                  │
│  ┌────┴─────┐       ┌────┴─────┐       ┌────┴─────┐           │
│  │  HSM-01  │◄─────►│  HSM-02  │◄─────►│  HSM-03  │           │
│  │  (AZ1)   │       │  (AZ2)   │       │  (AZ3)   │           │
│  │  Primary  │       │  Replica │       │  Replica │           │
│  └──────────┘       └──────────┘       └──────────┘           │
│                                                                   │
│  Replicação síncrona de chaves entre appliances                  │
│  Quorum: 2/3 para operações de escrita                           │
└─────────────────────────────────────────────────────────────────┘
```

## Hardware HSM — Requisitos Técnicos

### Appliance HSM (Network HSM)

| Atributo | Requisito Técnico |
|----------|-------------------|
| Form factor | Appliance de rede 1U, rack-mount |
| Certificação | FIPS 140-2 Level 3 (ou FIPS 140-3 Level 3) |
| Performance | ≥ 20.000 operações RSA-2048 sign/s |
| Algoritmos | RSA (1024-4096), ECC (P-256, P-384, P-521), AES (128/192/256), SHA-2 (256/384/512), HMAC, 3DES |
| Partições | ≥ 100 partições isoladas por appliance |
| Conectividade | 2x portas 1GbE em bonding para HA |
| API | PKCS#11 v2.40+, KMIP 1.4+ |
| HA | Suporte a replicação síncrona de chaves e HA group entre múltiplas unidades |
| Tamper Response | Detecção física com zeroização automática de chaves em violação |
| Backup | Suporte a backup criptografado para appliance offline ou cofre físico |
| Auditoria | Trilha de auditoria interna + exportação via syslog |
| Role Separation | Suporte a papéis distintos: Crypto Officer (CO), Auditor (AU), Security Officer (SO) |

### Distribuição por AZ

| Appliance | AZ | Rack | Rede | Função |
|-----------|----|----|------|--------|
| hsm-az1-01 | AZ1 | R1 (U39) | 10.0.200.21 | Primary |
| hsm-az2-01 | AZ2 | R4 (U39) | 10.0.200.22 | Replica |
| hsm-az3-01 | AZ3 | R7 (U39) | 10.0.200.23 | Replica |

## Arquitetura de Alta Disponibilidade

```
┌──────────────────────────────────────────────────────────────┐
│                    HA Group (HSM Cluster)                     │
│                                                                │
│  ┌────────────┐     ┌────────────┐     ┌────────────┐       │
│  │  HSM AZ1   │     │  HSM AZ2   │     │  HSM AZ3   │       │
│  │  Partition  │     │  Partition  │     │  Partition  │       │
│  │  "barbican" │     │  "barbican" │     │  "barbican" │       │
│  └──────┬─────┘     └──────┬─────┘     └──────┬─────┘       │
│         │                   │                   │              │
│         └───────────────────┼───────────────────┘              │
│                             │                                  │
│                    ┌────────┴────────┐                        │
│                    │   HA Group      │                        │
│                    │  Mode: active   │                        │
│                    │  (all active)   │                        │
│                    └─────────────────┘                        │
│                                                                │
│  Política: operações apenas via HA group                       │
│  Recuperação: automatic failover + auto-recovery              │
└──────────────────────────────────────────────────────────────┘
```

### Modos de HA

| Modo | Descrição | Uso |
|------|-----------|-----|
| Active-Active | Todas as partições ativas, load-balanced | **Produção** |
| Active-Passive | Primary ativo, replicas em standby | DR |
| Standalone | Sem HA, partição única | Lab/Dev |

### Tolerância a Falhas

| Cenário | Impacto | Recuperação |
|---------|---------|-------------|
| 1 HSM indisponível | Nenhum (2/3 operacionais) | Auto-failover < 1s |
| 2 HSMs indisponíveis | Operações read-only | Manual recovery |
| 3 HSMs indisponíveis | Serviço indisponível | Restore from backup |
| Tamper em 1 HSM | Zeroização local, cluster continua | Substituição + re-sync |

## Integração Barbican + PKCS#11

### Configuração Barbican

```ini
# /etc/barbican/barbican.conf
[DEFAULT]
sql_connection = mysql+pymysql://barbican:PASS@10.0.200.5/barbican

[secretstore]
enabled_secretstore_plugins = store_crypto

[crypto]
enabled_crypto_plugins = p11_crypto

[p11_crypto_plugin]
# Biblioteca PKCS#11 fornecida pelo vendor do HSM
library_path = /usr/lib/libCryptoki2_64.so

# HA Group slot (virtual slot do HA group)
slot_id = 1

# Credenciais da partição
login = PARTITION_PASSWORD

# Master KEK (Key Encryption Key) label no HSM
mkek_label = barbican-mkek
mkek_length = 32

# HMAC key label
hmac_label = barbican-hmac
hmac_key_type = CKK_AES
hmac_keywrap_mechanism = CKM_AES_CBC_PAD

# Token labels
token_serial_number = HSM_HA_GROUP
token_label = barbican-ha

# Encryption mechanism
encryption_mechanism = CKM_AES_CBC_PAD
seed_file = /etc/barbican/seed.bin
seed_length = 32
```

### PKCS#11 Client Configuration

```ini
# Exemplo genérico de configuração do cliente PKCS#11
# O arquivo específico e o formato variam conforme o vendor do HSM.
# Requisitos funcionais:
#   - Biblioteca libCryptoki2_64.so (ou equivalente PKCS#11 v2.40+)
#   - Suporte a NTLS (Network Trust Link) ou TLS mútuo para conexão com os appliances
#   - Configuração de HA group listando os três appliances

HSMClient = {
  # Timeouts
  ReceiveTimeout = 20000;
  TCPKeepAlive = 1;
  NetClient = 1;

  # Appliances do cluster
  ServerName00 = hsm-az1-01;
  ServerPort00 = 1792;

  ServerName01 = hsm-az2-01;
  ServerPort01 = 1792;

  ServerName02 = hsm-az3-01;
  ServerPort02 = 1792;
}

HASynchronize = {
  HAOnly = 1;
}

HAConfiguration = {
  AutoReconnectInterval = 60;
  reconnAtt = -1;

  HAGroup00 = {
    Label = barbican-ha;
    Members = hsm-az1-01,hsm-az2-01,hsm-az3-01;
  }
}
```

## Hierarquia de Chaves

```
┌─────────────────────────────────────────────────────────┐
│                HSM (FIPS 140-2 Level 3)                  │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Master KEK (MKEK)                              │    │
│  │  AES-256, nunca sai do HSM                      │    │
│  │  Label: barbican-mkek                           │    │
│  └────────────────────────┬────────────────────────┘    │
│                           │ wraps                        │
│  ┌────────────────────────┴────────────────────────┐    │
│  │  Project KEKs (pKEK)                            │    │
│  │  AES-256, wrapped pelo MKEK                     │    │
│  │  1 por projeto OpenStack                        │    │
│  └────────────────────────┬────────────────────────┘    │
│                           │ wraps                        │
└───────────────────────────┼─────────────────────────────┘
                            │
┌───────────────────────────┴─────────────────────────────┐
│  Data Encryption Keys (DEK)                              │
│  Armazenados encrypted no Barbican DB                    │
│  Usados por: Cinder (LUKS), Swift, Nova, Octavia        │
└─────────────────────────────────────────────────────────┘
```

## Operações Criptográficas

### Fluxo de Criação de Secret

```
1. Tenant → Barbican API: POST /v1/secrets
2. Barbican → PKCS#11 Plugin: generate DEK
3. PKCS#11 → HSM: C_GenerateKey (AES-256)
4. HSM → PKCS#11: DEK (plaintext, in-memory only)
5. PKCS#11 → HSM: C_WrapKey (DEK com pKEK)
6. HSM → PKCS#11: wrapped DEK (ciphertext)
7. Barbican → DB: store wrapped DEK
8. Barbican → Tenant: secret reference
```

### Fluxo de Recuperação de Secret

```
1. Tenant → Barbican API: GET /v1/secrets/{id}/payload
2. Barbican → DB: retrieve wrapped DEK
3. Barbican → PKCS#11 → HSM: C_UnwrapKey (wrapped DEK com pKEK)
4. HSM → PKCS#11: DEK (plaintext)
5. Barbican → Tenant: secret payload
```

## Integração com Serviços OpenStack

| Serviço | Uso do HSM (via Barbican) | Tipo de Chave |
|---------|---------------------------|---------------|
| Cinder | Volume encryption keys (LUKS) | AES-256 |
| Nova | Ephemeral disk encryption | AES-256 |
| Swift | Object encryption at-rest | AES-256 |
| Octavia | TLS certificates (private keys) | RSA-2048/4096, EC P-256 |
| Glance | Image signature verification | RSA-2048 |
| Neutron | VPN pre-shared keys | AES-256 |
| Keystone | Fernet key wrapping | AES-256 |

## Gestão de Chaves

### Key Lifecycle

| Fase | Ação | Frequência |
|------|------|-----------|
| Geração | C_GenerateKey no HSM | On-demand |
| Ativação | Imediata após geração | Automática |
| Rotação | MKEK rotation via pkcs11-kek-rewrap | 365 dias |
| Revogação | Soft-delete + crypto shredding | On-demand |
| Destruição | C_DestroyObject no HSM | Após retention period |

### MKEK Rotation

```bash
# Gerar novo MKEK no HSM
barbican-manage hsm mkek_generate \
  --label barbican-mkek-2026 \
  --length 32

# Re-wrap todos os pKEKs com novo MKEK
pkcs11-kek-rewrap \
  --old-mkek-label barbican-mkek \
  --new-mkek-label barbican-mkek-2026

# Atualizar configuração
# mkek_label = barbican-mkek-2026
```

## Segurança e Compliance

### Controles FIPS 140-2 Level 3

| Controle | Implementação |
|----------|---------------|
| Tamper Evidence | Selos físicos, sensores de intrusão |
| Tamper Response | Zeroização automática de chaves |
| Identity-Based Auth | Partição com password + PED (opcional) |
| Physical Security | Rack trancado, acesso auditado |
| Key Zeroization | Destruição criptográfica em violação |
| Audit Logging | Syslog + HSM internal audit trail |
| Role Separation | CO (Crypto Officer), AU (Auditor), SO (Security Officer) |

### Audit Trail

```ini
# /etc/barbican/barbican.conf
[oslo_messaging_notifications]
driver = messagingv2
topics = notifications,barbican_audit

# Eventos auditados:
# - Secret create/read/delete
# - Key rotation
# - HSM connection events
# - Authentication failures
```

## Monitoramento

| Métrica | Fonte | Alerta |
|---------|-------|--------|
| HSM Reachability | barbican health check | Unreachable > 5s |
| PKCS#11 Latency | barbican metrics | P99 > 50ms |
| HA Group Members | PKCS#11 client | Members < 3 |
| Partition Usage | HSM admin | > 80% key slots |
| HSM Temperature | SNMP/IPMI | > 40°C |
| Failed Auth Attempts | HSM audit log | > 3 in 5min |
| Key Operations/sec | barbican metrics | > 15.000/s (capacity) |

## Backup e DR

### Backup Strategy

```
┌──────────────┐     ┌──────────────┐
│  Backup HSM  │     │  Offline     │
│  offline     │◄────│  Storage     │
│  (dedicado)  │     │  (cofre)     │
└──────────────┘     └──────────────┘

Procedimento:
1. Conectar appliance de backup ao HSM primary (via USB ou via rede, conforme vendor)
2. Executar partition backup (criptografado pelo HSM)
3. Armazenar mídia de backup em cofre físico (site separado)
4. Frequência: semanal + após cada key rotation
```

### Recovery

| Cenário | RTO | RPO | Procedimento |
|---------|-----|-----|--------------|
| 1 HSM failure | < 1s | 0 | Auto-failover (HA group) |
| Full cluster loss | 4h | Last backup | Restore from HSM backup offline |
| Key compromise | 1h | 0 | Revoke + re-encrypt affected data |

## Rede e Conectividade

```
┌─────────────────────────────────────────────────────────┐
│  VLAN 200 (DB/HSM Replication) — Isolada                 │
│                                                           │
│  Controller Nodes ──► HSM Appliances (port 1792/TCP)     │
│  (Barbican)           (NTLS — Network Trust Link / mTLS) │
│                                                           │
│  Firewall Rules:                                         │
│  - ALLOW 10.0.200.0/24 → HSM:1792 (NTLS/PKCS#11)        │
│  - ALLOW 10.0.200.0/24 → HSM:22 (admin SSH, restrito)   │
│  - DENY ALL other                                        │
└─────────────────────────────────────────────────────────┘
```

## Decisões Arquiteturais

1. **HSM network appliance FIPS 140-2 Level 3**: Padrão de mercado para KMS em nuvem privada; suporte nativo a PKCS#11 para integração com Barbican
2. **FIPS 140-2 Level 3**: Requisito para compliance financeiro (PCI-DSS) e governamental
3. **3 HSMs (1 por AZ)**: Tolerância a falha de AZ inteira sem perda de serviço
4. **HA Group Active-Active**: Todas as partições ativas, load-balanced, sem single point of failure
5. **PKCS#11 (não KMIP)**: Performance superior, integração nativa com Barbican p11_crypto plugin
6. **MKEK nunca sai do HSM**: Chave mestra protegida por hardware — impossível extrair
7. **Hierarquia KEK→pKEK→DEK**: Permite rotação de MKEK sem re-encrypt de todos os dados
8. **Rede isolada (VLAN 200)**: HSMs acessíveis apenas pelos controllers, sem exposição a tenants
9. **Requisitos agnósticos de marca**: Especificação baseada em certificações (FIPS), APIs (PKCS#11, KMIP) e capabilities — permite múltiplos fornecedores compatíveis

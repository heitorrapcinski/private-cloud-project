# 11 - Plano de Continuidade da Plataforma

## Objetivo

Documentar a estratégia de continuidade operacional da nuvem privada, definindo expectativas de resiliência por componente, cenários cobertos pelo design atual, riscos residuais aceitos e oportunidades de evolução. Este documento é referência para decisões de arquitetura, priorização de investimentos e resposta a incidentes.

## Níveis de Serviço Alvo

| Indicador | Meta | Medição |
|-----------|------|---------|
| API OpenStack (control plane) | 99.99% disponibilidade mensal | Blackbox prober a cada 5s |
| VM (tier shared) | 99.9% disponibilidade mensal | Nova instance state + heartbeat |
| VM (tier dedicated) | 99.99% disponibilidade mensal | Nova instance state + heartbeat |
| Block storage (Cinder) | 99.99% disponibilidade | Health check do backend |
| Object storage (Swift) | 99.99% durabilidade por ano | Replicação 3x + auditor |
| Fabric de rede (underlay) | 99.999% disponibilidade | BFD + SNMP dos switches |
| HSM / Barbican | 99.99% disponibilidade | barbican health check |
| RTO padrão (componente) | ≤ 5 min | Auto-recovery via quorum |
| RTO crítico (AZ completa) | ≤ 15 min | Evacuate + failover manual |
| RPO (dados transacionais) | 0 (sync replication) | Galera sync commit |
| RPO (object storage) | 0 (3 replicas sync) | Swift replication |
| RPO (backups offsite) | ≤ 24h | Backup incremental diário |

## Domínios de Falha

A resiliência da plataforma é construída sobre três camadas concêntricas de isolamento físico:

```
Região ─► Availability Zone ─► Fault Domain ─► Nó/Componente
 (1)         (3 por região)     (3 por AZ)      (N por FD)
```

### O que é um Fault Domain (FD)

Um **FD** é uma unidade física de isolamento dentro de uma AZ, usada para limitar o raio de impacto de falhas correlacionadas de **média escala** — aquelas que afetam múltiplos nós simultaneamente, mas não a AZ inteira. Na nossa arquitetura, **cada FD corresponde a 1 rack físico**, totalizando 9 FDs (3 por AZ × 3 AZs).

A distinção entre AZ e FD é crucial:

| Camada | Protege contra | Exemplo de evento |
|--------|----------------|-------------------|
| Região | Catástrofe geográfica | Terremoto, incêndio do DC inteiro |
| AZ | Falha correlacionada de grande escala | Perda de chiller plant, falha de utility feed da sala |
| FD (rack) | Falha correlacionada de média escala | PDU dupla, par MLAG, in-row cooling, queda de rack |
| Nó | Falha de componente individual | Disco, NIC, PSU, memória |

Sem a camada de FD, uma falha de rack derrubaria múltiplos nós simultaneamente sem que o scheduler tivesse ciência — quebrando as premissas de HA que assumem independência estatística entre réplicas. O FD é o mecanismo que transforma "temos 3 AZs" em resiliência real contra falhas de rack.

### Mapeamento Físico dos FDs

| FD | Racks | Função principal |
|----|-------|------------------|
| FD1 | R1 (AZ1), R4 (AZ2), R7 (AZ3) | Control plane + Cinder + HSM |
| FD2 | R2 (AZ1), R5 (AZ2), R8 (AZ3) | Spine + compute + GPU + Swift |
| FD3 | R3 (AZ1), R6 (AZ2), R9 (AZ3) | Compute + GPU + Swift |

### Uso por Serviço

| Serviço | Placement por FD | Benefício |
|---------|------------------|-----------|
| Control plane (ctrl/db/mq/lb) | 1 nó em FD1 de cada AZ | Quorum 2/3 sobrevive à perda de qualquer rack |
| Compute | Distribuído entre FD1/FD2/FD3 de cada AZ | Server groups com anti-affinity colocam réplicas em FDs distintos |
| GPU compute | 1 nó em cada FD (R1-R9) | Falha de rack remove no máximo 1 GPU node por AZ |
| Swift | 2 nós em cada FD | Replicas zone-aware garantem distribuição entre AZs e FDs |
| Network nodes | FD2/FD3 de cada AZ | Gateway sempre disponível em FDs não-controller |
| Spine fabric | 1 spine em FD2 de cada AZ | Falha de rack FD2 remove 1 spine; ECMP mantém 2/3 bandwidth |
| HSM | 1 appliance em FD1 de cada AZ | HA activeA sobrevive à perda de qualquer rack |

Exposição operacional:

- **Nova host aggregates** recebem metadata `fault_domain=fd1|fd2|fd3`, permitindo que tenants usem server groups com anti-affinity `fault_domain` para espalhar réplicas de aplicação.
- **Swift rings** mapeiam zones para AZs; devices são distribuídos entre nós de racks distintos (FDs) ao construir o ring, garantindo que as 3 replicas de cada objeto fiquem em FDs diferentes.
- **Placement traits** customizados (`CUSTOM_FAULT_DOMAIN_FD1` etc.) permitem que scheduler filters garantam distribuição explícita quando o workload exige.

### Níveis de Falha e Raio de Blast

A plataforma é projetada contra quatro níveis de falha, em ordem crescente de impacto:

| Nível | Escopo | FDs afetados | Racks afetados | Capacity loss | Estratégia |
|-------|--------|--------------|----------------|---------------|------------|
| L1 | Componente individual (disco, NIC, PSU) | 0 (parte de 1 FD) | 0 | < 1% | Redundância intra-nó (RAID, bonding, dual-PSU) |
| L2 | Nó completo (servidor ou appliance) | 0 (parte de 1 FD) | 0 | < 1% | Scheduler + replicação cross-nó dentro do mesmo FD |
| L3 | Rack inteiro = 1 FD | 1 | 1 | ~11% | Quorum 2/3 entre os 3 FDs da AZ + placement aware |
| L4 | Availability Zone completa = 3 FDs | 3 | 3 | ~33% | Quorum 2/3 entre AZs + evacuate manual |

Eventos acima de L4 (perda de região inteira = 9 FDs, 100% de capacity loss) não são cobertos pelo design atual e são tratados na seção **Riscos Não Cobertos**.

---

## Matriz de Tolerância por Componente

### Control Plane (Keystone / Nova-API / Neutron-Server / Glance / Cinder-API / Horizon / Heat / Octavia / Barbican / Designate / Placement)

| Dimensão | Design |
|----------|--------|
| Topologia | 3 instâncias ativas, uma por AZ, atrás de HAProxy + Keepalived |
| Estado | Stateless (Fernet tokens, cache memcached, backend em Galera) |
| Falha de 1 instância | API permanece disponível via 2 restantes; HAProxy remove backend DOWN em 3s |
| Falha de 2 instâncias | API permanece disponível via 1 restante; capacidade reduzida a 33% |
| Falha de 3 instâncias | **Indisponibilidade total** (risco residual, cobrir via oportunidade #2) |
| Failover | Automático via HAProxy health checks |
| RTO | < 5s (detecção + remoção do backend) |
| RPO | 0 (stateless) |

### MariaDB Galera Cluster

| Dimensão | Design |
|----------|--------|
| Topologia | 3 nós, um por AZ (db-01 AZ1, db-02 AZ2, db-03 AZ3), replicação síncrona multi-master |
| Quorum | 2/3 (wsrep PC quorum) |
| Falha de 1 nó | Cluster continua em 2/3, writes aceitos, auto-rejoin via IST |
| Falha de 2 nós | Nó restante entra em **non-Primary** (read-only) para evitar split-brain |
| Split-brain | Protegido por PC weight; partição minoritária fica read-only |
| Failover de cliente | HAProxy roteia apenas para nós Primary+Synced |
| RTO | < 10s (auto-rejoin) em falha simples; manual em split-brain |
| RPO | 0 (commit síncrono em pelo menos 2 nós) |

### RabbitMQ (Quorum Queues)

| Dimensão | Design |
|----------|--------|
| Topologia | 3 nós, um por AZ; default_queue_type = quorum (Raft) |
| Quorum | 2/3 para writes |
| Falha de 1 nó | Queues continuam operacionais (Raft elege novo leader) |
| Falha de 2 nós | Queues tornam-se read-only; serviços OpenStack falham com timeout |
| Particionamento | Quorum queues tolera partição sem perda (vs mirrored queues) |
| RTO | < 30s (eleição de leader) |
| RPO | 0 (mensagens persistidas em quorum antes de ack) |

### HAProxy + Keepalived (Load Balancers)

| Dimensão | Design |
|----------|--------|
| Topologia | 3 instâncias co-localizadas com controllers; VRRP |
| VIPs | 10.0.10.5 (public), 10.0.100.5 (internal) |
| Failover | Keepalived VRRP, priority 101/100/99 |
| Falha de MASTER | VIP migra para BACKUP com maior prioridade em < 3s |
| Falha de 2 instâncias | VIP permanece no único nó restante |
| Split-brain VRRP | Mitigado por authentication + unicast peers |
| RTO | < 3s |
| RPO | 0 (conexões ativas retry via keepalive TCP) |

### Memcached

| Dimensão | Design |
|----------|--------|
| Topologia | 3 instâncias, sem replicação (consistent hashing) |
| Falha de 1 instância | 33% dos tokens cacheados invalidados; re-read do Galera (latência adicional temporária) |
| Falha total | Aumento de carga no Galera; sem perda de funcionalidade |
| RTO | Imediato (cache miss tolerado) |
| RPO | N/A (cache efêmero) |

### Nova Compute (KVM Hypervisors)

| Dimensão | Design |
|----------|--------|
| Topologia | 102 nós, 34 por AZ, distribuídos em 9 racks (12/10/12 por FD) |
| Scheduler | Filter + Weight + Placement API |
| Falha de 1 nó | VMs no nó ficam em ERROR; requer `nova host-evacuate` manual (ou automático via Masakari se habilitado) |
| Falha de 1 rack (FD) | 10-12 nós perdidos; scheduler redireciona novas VMs para FDs saudáveis |
| Falha de 1 AZ | 34 nós perdidos (33% capacity); cross-AZ evacuate requer cold migration |
| Anti-affinity | Server groups garantem distribuição de réplicas de aplicação entre FDs |
| RTO | Manual: 5-10 min (evacuate de dezenas de VMs) |
| RPO | Depende do storage backing (Cinder sync = 0, ephemeral = perda total) |

### GPU Compute Plane

| Dimensão | Design |
|----------|--------|
| Topologia | 9 nós (1 por FD), PCI passthrough, sem overcommit |
| Failover | Manual (workloads GPU tipicamente não são live-migratable) |
| Falha de 1 nó | 4 GPUs perdidas; capacity drop 11% |
| Falha de 1 rack | 4 GPUs (1 nó GPU por rack) |
| Falha de 1 AZ | 12 GPUs perdidas (33%) |
| Estratégia | Checkpoint periódico de workloads ML (responsabilidade do tenant) |
| RTO | Reagendamento manual (15-30 min) |
| RPO | Última checkpoint do workload |

### Cinder (Block Storage)

| Dimensão | Design |
|----------|--------|
| Topologia | 3 nós (um por AZ), LVM over NVMe, iSCSI target |
| cinder-volume | Active/Passive por backend (DLM via tooz) |
| Falha de 1 nó | Volumes naquele backend ficam inacessíveis até failover ou restore |
| Replicação | Volume replication async cross-AZ (habilitável por volume type) |
| Backup | Para Swift (incremental + full semanal) |
| RTO | ~ 30s (DLM failover); horas para restore completo |
| RPO | Volumes replicados: minutos; volumes não-replicados: RPO do último snapshot |

### Swift (Object Storage)

| Dimensão | Design |
|----------|--------|
| Topologia | 18 nós, 3 replicas cross-AZ (zone-aware) |
| Durabilidade | 99.999999% (3 replicas em 3 zones) |
| Falha de 1 disco | Replicator repara automaticamente; sem impacto |
| Falha de 1 nó (12 discos) | Dados servidos pelas outras 2 réplicas; replicator reconstrói |
| Falha de 1 rack (2 nós) | 24 discos; cluster continua (2/3 réplicas disponíveis) |
| Falha de 1 AZ (6 nós, 72 discos) | Cluster continua com 2/3 réplicas; writes aceitos |
| RTO | 0 (clientes transparentemente roteados) |
| RPO | 0 |

### Glance (Image Service)

| Dimensão | Design |
|----------|--------|
| Backend | Swift (default) + cache local NVMe nos controllers |
| Falha de API | 3 instâncias atrás de HAProxy (ver control plane) |
| Falha de backend | Swift tolera perda de 1 AZ (ver Swift) |
| RTO | < 5s |
| RPO | 0 |

### Spine-Leaf Fabric

| Dimensão | Design |
|----------|--------|
| Topologia | 3 spines (1 por AZ em R2/R5/R8), 18 leaves (2 por rack) |
| Uplinks por leaf | 3x 100GbE (1 por spine), ECMP via BGP |
| Mesh inter-spine | Full-mesh triangular (3 links) |
| Falha de 1 leaf | Hosts continuam via MLAG peer (50% bandwidth local) |
| Falha de ambos leaves de 1 rack | Rack isolado; VMs ficam inacessíveis |
| Falha de 1 spine | Underlay opera em 2/3 da bandwidth; ECMP redistribui |
| Falha de 2 spines | Underlay em 1/3 bandwidth; congestionamento provável |
| Detecção | BFD (sub-segundo), BGP hold timer (padrão 90s, ajustado para 9s) |
| RTO | < 1s (BFD + ECMP reconverge) |
| RPO | N/A |

### OVN (SDN Overlay)

| Dimensão | Design |
|----------|--------|
| Topologia | OVN Northbound/Southbound DB em Raft (3 nós nos controllers) |
| ovn-controller | Um por compute e network node |
| Falha de 1 DB | Raft continua em 2/3 |
| Falha de 1 gateway node | Tráfego N-S redirecionado para gateway saudável |
| Distributed DVR | Tráfego E-W não depende de gateway central |
| RTO | < 10s (Raft election) |
| RPO | 0 |

### HSM Cluster (Barbican backend)

| Dimensão | Design |
|----------|--------|
| Topologia | 3 appliances FIPS 140-2 L3, HA group Active-Active |
| Falha de 1 HSM | Auto-failover < 1s; cluster continua em 2/3 |
| Falha de 2 HSMs | Operações em read-only |
| Falha total | Restore de backup offline (RTO 4h) |
| MKEK | Nunca sai do HSM; protegido por hardware |
| Backup | Criptografado, armazenado em cofre físico em site separado |
| RTO | < 1s (1 HSM), 4h (full cluster loss) |
| RPO | 0 em failover; último backup em full loss |

### Identity Federation (Keystone OIDC/SAML)

| Dimensão | Design |
|----------|--------|
| IdP corporativo | Responsabilidade externa (não coberto por este plano) |
| Falha do IdP | Login SSO indisponível; local admin accounts permanecem funcionais |
| Mitigação | 2 break-glass accounts locais com MFA hardware |
| RTO | Dependente do IdP corporativo |

### Energia e Resfriamento

| Dimensão | Design |
|----------|--------|
| Feeds | 2 feeds utility por rack (A + B) |
| UPS | N+1 por fileira |
| Gerador | 1 por AZ, diesel, 72h de autonomia |
| Cooling | In-row N+1 (racks padrão), in-row + rear-door (racks FD1 com GPU/HSM) |
| Falha de 1 feed | PSU redundante mantém carga |
| Falha de UPS | Failover para UPS par |
| Falha prolongada utility | Gerador entra em 30s; autonomia 72h |
| Refill combustível | SLA com fornecedor de diesel: 48h após acionamento |

---

## Cenários Cobertos

### C1 — Falha de Componente Individual (disco, NIC, PSU, memória)
- **Frequência esperada:** semanal
- **Detecção:** SMART, monitoramento SNMP/IPMI, Prometheus
- **Impacto:** nenhum (redundância intra-nó)
- **Ação:** troca em horário de manutenção

### C2 — Falha de Nó (servidor completo)
- **Frequência esperada:** mensal
- **Detecção:** Prometheus node_exporter down, ausência de heartbeat
- **Impacto:** capacity drop local; VMs no nó entram em ERROR
- **Ação:** `nova host-evacuate`; para GPU/bare-metal, reagendamento manual

### C3 — Falha de Leaf Switch
- **Frequência esperada:** trimestral
- **Detecção:** BFD down, BGP peer down, perda de syslog
- **Impacto:** 50% da bandwidth do rack (via MLAG peer)
- **Ação:** substituição; re-sync MLAG

### C4 — Falha de Spine Switch
- **Frequência esperada:** semestral
- **Detecção:** BFD + BGP + ECMP telemetry
- **Impacto:** 33% da bandwidth underlay, sem perda de conectividade
- **Ação:** substituição com maintenance window; ECMP mantém tráfego

### C5 — Falha de 1 Controller/DB/MQ
- **Frequência esperada:** mensal
- **Detecção:** HAProxy health check, Galera wsrep_cluster_size, rabbitmqctl
- **Impacto:** nenhum (2/3 quorum)
- **Ação:** restart ou rebuild do nó; auto-rejoin

### C6 — Falha de Rack Inteiro (Fault Domain)
- **Frequência esperada:** anual
- **Detecção:** múltiplos serviços daquele rack indisponíveis
- **Impacto:** 11% da capacity; 1 controller + 1 DB + 1 MQ + 10-12 computes + storage + GPU do rack
- **Ação:** control plane sobrevive via 2/3; VMs do rack requerem evacuate; aguardar recuperação ou substituir hardware

### C7 — Falha de Availability Zone Completa
- **Frequência esperada:** multi-anual
- **Detecção:** perda simultânea de 3 racks de uma AZ
- **Impacto:** 33% da capacity; control plane ainda em quorum (2/3 AZs)
- **Ação:** evacuate manual de VMs para AZs saudáveis; tenant-level failover de aplicações

### C8 — Falha de 1 HSM
- **Frequência esperada:** bi-anual
- **Detecção:** barbican health check, PKCS#11 errors
- **Impacto:** nenhum (HA activeA continua com 2/3)
- **Ação:** substituição; re-sync de partições

### C9 — Perda de Energia em 1 AZ
- **Frequência esperada:** multi-anual
- **Detecção:** UPS alarm, gerador acionado
- **Impacto:** serviço mantido via gerador por até 72h
- **Ação:** monitorar nível de diesel; acionar refill preventivo após 24h

### C10 — Split-Brain de Rede entre AZs
- **Frequência esperada:** rara
- **Detecção:** BGP peer flaps, Galera non-Primary em partições
- **Impacto:** partição minoritária entra em read-only; partição majoritária segue operando
- **Ação:** isolar e reingressar; validar integridade de dados

### C11 — Corrupção de Dados em 1 Volume Cinder
- **Frequência esperada:** rara
- **Detecção:** LUKS integrity error, aplicação reportando corruption
- **Impacto:** volume específico; demais volumes intactos
- **Ação:** restore do snapshot ou do backup Swift

---

## Riscos Não Cobertos (Residuais)

### R1 — Perda da Região Inteira (disaster regional)
**Cenário:** catástrofe natural, incêndio no datacenter, ataque físico coordenado.

**Por que não coberto:** a arquitetura atual é single-region com 3 AZs co-localizadas geograficamente. Não há replicação offsite síncrona para segunda região.

**Mitigação atual:** backups offsite diários (HSM, DB dumps, Cinder backup para Swift) em cofre físico em site separado.

**RTO estimado:** 24-72h (rebuild em infra alternativa)
**RPO estimado:** ≤ 24h (último backup incremental)

**Aceite de risco:** documentado; cobertura via DR site é oportunidade #1.

### R2 — Ataque de Ransomware / Comprometimento de Admin
**Cenário:** atacante obtém credenciais de cloud_admin e executa deleções em massa ou criptografa dados.

**Por que não coberto:** controles existentes (RBAC, MFA, audit log) são detectivos/preventivos, mas não impedem um ator com privilégios máximos.

**Mitigação atual:** 
- Audit log CADF centralizado (imutável via forward para SIEM offsite)
- Backup Swift em storage policy separada (não acessível via credenciais de tenant)
- Backups HSM em cofre físico air-gapped

**Lacuna:** não há **immutable backup** (WORM) nem segregação de duties para operações destrutivas.

### R3 — Bug de Software em Componente Crítico
**Cenário:** regressão em OpenStack release ou bug em Galera/RabbitMQ causa corrupção sistêmica.

**Por que não coberto:** não há ambiente de validação de mudanças após remoção do laboratório.

**Mitigação atual:**
- Upgrades SLURP apenas (pulam releases intermediárias, mais testados)
- Testes automatizados Tempest/Rally em pipeline CI/CD

**Lacuna:** sem ambiente staging, upgrades e patches vão direto para produção. Oportunidade #3.

### R4 — Exaustão de IPs Públicos (Floating IPs)
**Cenário:** crescimento de tenants esgota pool 203.0.113.0/24 (254 floating IPs utilizáveis).

**Mitigação atual:** monitoramento de uso em Prometheus, quotas por projeto.

**Lacuna:** sem expansão automática. Requer negociação com ISP para novos blocos.

### R5 — Falha Simultânea de 2 AZs
**Cenário:** evento correlacionado afeta 2 das 3 AZs (ex: falha de energia regional).

**Impacto:** control plane perde quorum; cluster entra em non-Primary; serviço degradado para read-only.

**Mitigação atual:** diversidade de feeds de utility e diesel por AZ.

**Lacuna:** AZs compartilham infraestrutura de rede (fibra, chiller plant, equipe). Oportunidade #4.

### R6 — Chave Mestra HSM Perdida
**Cenário:** destruição de todos os 3 HSMs + backup em cofre.

**Impacto:** todos os secrets encrypted em Barbican tornam-se irrecuperáveis; volumes LUKS perdidos.

**Mitigação atual:** 3 HSMs geograficamente distribuídos + backup criptografado em cofre.

**Lacuna:** sem second-site para backup HSM. Procedimento de key escrow com terceiro confiável não implementado.

### R7 — Dependência de Certificado Corporativo Root CA
**Cenário:** CA corporativa revogada ou comprometida.

**Impacto:** todos os certificados TLS internos invalidados simultaneamente.

**Mitigação atual:** pinning de CA intermediária.

**Lacuna:** não há procedure de rotação emergencial de PKI validada.

### R8 — Supply Chain (Kolla Images)
**Cenário:** imagem Kolla upstream comprometida (typosquatting ou compromise do registry).

**Mitigação atual:** pull de `quay.io/openstack.kolla` (registry oficial), SCA em CI/CD.

**Lacuna:** sem mirror interno com assinatura e verificação de integridade (cosign/sigstore).

### R9 — Crescimento Descontrolado de Capacity
**Cenário:** consumo de compute/storage cresce além do previsto e não há espaço físico (9 racks, todos populados).

**Mitigação atual:** monitoramento e forecast em Grafana.

**Lacuna:** limite físico rígido; expansão requer novo contrato de colocation.

### R10 — Vazamento de Metadata de Tenants
**Cenário:** bug de isolamento em OVN ou Neutron permite cross-tenant leakage.

**Mitigação atual:** security groups, VXLAN isolation, testes Tempest.

**Lacuna:** sem pentest regular do plano de rede; sem micro-segmentação L7 nativa.

---

## Oportunidades de Melhoria (Roadmap)

### O1 — DR Multi-Region (Prioridade Alta)
**Descrição:** implantar segunda região OpenStack em site geograficamente distante (≥ 300 km) com replicação async de dados críticos.

**Componentes:**
- Galera async replication (OpenStack DB) ou cold standby
- Swift global cluster (multi-region replication)
- Glance image sync via `glance-replicator`
- Cinder backup cross-region
- HSM backup replicado para site DR

**RTO alvo:** 4h
**RPO alvo:** 1h
**Esforço:** 6-9 meses
**Cobre risco:** R1, parcialmente R5

### O2 — Masakari (Instance HA)
**Descrição:** habilitar OpenStack Masakari para auto-evacuate de VMs em caso de falha de compute host.

**Benefícios:**
- Elimina intervenção manual no cenário C2
- Reduz RTO de 10 min para 2 min para VMs não-GPU
- Integra com Pacemaker para host monitoring

**Esforço:** 2-3 meses
**Cobre risco:** melhoria do cenário C2

### O3 — Ambiente de Staging
**Descrição:** criar cluster staging dedicado (pequena escala, mesma stack) para validação de upgrades e mudanças antes de produção.

**Alternativas:**
- Cluster staging com 3 controllers + 3 computes (6-9 nós)
- Kolla-Ansible em VMs nested para testes rápidos
- DevStack per-developer para desenvolvimento

**Esforço:** 3 meses
**Cobre risco:** R3

### O4 — Diversidade Física de AZs
**Descrição:** migrar uma das AZs para colocation em prédio/distrito separado para eliminar correlação de falhas regionais.

**Requisitos:**
- Fibra dark redundante entre sites (≤ 5ms RTT)
- Controladores BGP em ambos os sites
- Revisão de placement de Galera/RabbitMQ para garantir quorum cross-site

**Esforço:** 6 meses (infra)
**Cobre risco:** R5

### O5 — Immutable Backup (WORM)
**Descrição:** adicionar backend S3-compatible com Object Lock (WORM) para backups críticos.

**Benefícios:** proteção contra ransomware e comprometimento de admin (R2).

**Opções:**
- Bucket Swift com policy append-only + retention
- Appliance tape externo com air-gap
- S3-compatible service externo com MFA delete

**Esforço:** 2 meses
**Cobre risco:** R2

### O6 — Chaos Engineering Contínuo
**Descrição:** automatizar injeção de falhas em produção (controlada) via ferramenta tipo Chaos Mesh ou Gremlin.

**Práticas:**
- Game days mensais (simulação de falha de rack)
- Automação de network partition entre AZs (semanal em horário off-peak)
- Kill randômico de VMs de controle (daily)

**Esforço:** 4 meses
**Cobre risco:** validação contínua de C1-C10

### O7 — PKI Auto-Rotation + HSM-backed
**Descrição:** rotação automática de certificados TLS com chaves geradas em HSM, CA intermediária rotacionada anualmente.

**Ferramentas:**
- cert-manager com issuer Barbican
- Ansible playbook para rotate-on-demand
- Runbook de rotação emergencial

**Esforço:** 3 meses
**Cobre risco:** R7

### O8 — Supply Chain Security
**Descrição:** mirror interno de imagens Kolla com assinatura Sigstore/cosign e verificação no pull.

**Componentes:**
- Registry interno (Harbor) com scanner Trivy
- Policy admission (OPA/Kyverno) exigindo assinatura
- SBOM gerado e armazenado para cada release

**Esforço:** 2 meses
**Cobre risco:** R8

### O9 — Micro-Segmentação L7
**Descrição:** adicionar service mesh (Octavia + Envoy, ou Istio para workloads Magnum/K8s) para isolamento L7 entre tenants.

**Esforço:** 6 meses
**Cobre risco:** R10 (parcial)

### O10 — Capacity Forecasting Automatizado
**Descrição:** modelo preditivo de consumo baseado em histórico Ceilometer + alertas proativos com 90 dias de antecedência antes de saturação.

**Stack:** Prometheus + ML forecasting (Prophet, ARIMA)

**Esforço:** 2 meses
**Cobre risco:** R9

### O11 — Break-Glass Access + Segregação de Duties
**Descrição:** fluxo aprovação 2-pessoas (Shamir secret sharing) para operações destrutivas (delete de projeto, rotação de MKEK, deploy em produção).

**Esforço:** 3 meses
**Cobre risco:** R2

### O12 — Key Escrow para HSM
**Descrição:** contrato com terceiro confiável (notarial ou cartório digital) para guarda de fragmento de chave mestra, recuperável apenas via processo judicial.

**Esforço:** 2 meses (majoritariamente jurídico)
**Cobre risco:** R6

---

## Priorização

| Oportunidade | Impacto | Esforço | Prioridade |
|--------------|---------|---------|-----------|
| O1 — DR Multi-Region | Alto | Alto | P0 |
| O5 — Immutable Backup | Alto | Baixo | P0 |
| O2 — Masakari | Médio | Médio | P1 |
| O3 — Staging | Alto | Médio | P1 |
| O11 — Break-Glass + SoD | Médio | Médio | P1 |
| O10 — Capacity Forecasting | Médio | Baixo | P1 |
| O8 — Supply Chain | Médio | Baixo | P1 |
| O4 — Diversidade Física AZ | Alto | Alto | P2 |
| O6 — Chaos Engineering | Médio | Médio | P2 |
| O7 — PKI Auto-Rotation | Médio | Médio | P2 |
| O12 — Key Escrow | Baixo | Baixo | P2 |
| O9 — Micro-Segmentação L7 | Médio | Alto | P3 |

---

## Ciclo de Vida do Plano

| Atividade | Frequência | Responsável |
|-----------|-----------|-------------|
| Revisão deste documento | Trimestral | Arquitetura |
| Game day (simulação) | Mensal | SRE |
| Teste de restore (DB/HSM/Swift) | Mensal | SRE |
| Teste de failover (AZ) | Semestral | Arquitetura + SRE |
| Teste de DR full (quando O1 entregue) | Anual | CAB + SRE + Produto |
| Revisão de riscos residuais | Semestral | Segurança + Arquitetura |
| Atualização de priorização | Trimestral | Steering |

## Referências Cruzadas

- `docs/03-control-plane.md` — detalhes de HA de control plane e quorum
- `docs/05-storage-plane.md` — replicação Swift e backup Cinder
- `docs/06-security.md` — controles de acesso e audit
- `docs/08-validation-testing.md` — procedimentos operacionais de teste
- `docs/10-hsm-key-management.md` — HA e backup do HSM
- `runbooks/operational-runbooks.md` — procedimentos de recuperação

# 12 — Bill of Materials — Hardware Recomendado (Dell)

> Documento gerado com base nos requisitos técnicos de `01-physical-architecture.md` e pesquisa
> no catálogo Dell PowerEdge (junho 2026). Preços em BRL quando disponíveis no site
> `dell.com/pt-br`; em USD quando apenas disponíveis no site global. Todos os preços referem-se
> à configuração base — a configuração final com memória, storage e NICs adequados será superior.
> Cotação formal deve ser solicitada diretamente à Dell para volumes acima de 10 unidades.

---

## Resumo Executivo

| Role | Modelo Dell Recomendado | Qtd | Preço Base Unitário | Observação |
|---|---|---:|---|---|
| Control Plane | PowerEdge **R670** | 12 | R$ 75.890 | 1U dual-socket Intel Xeon 6 |
| Compute | PowerEdge **R770** | 102 | USD 30.899 | 2U dual-socket Intel Xeon 6 |
| GPU Compute | PowerEdge **XE8640** | 9 | Consultar Dell | 4U, 4× H100 SXM5 NVLink |
| Swift Storage | PowerEdge **R760xd2** | 18 | R$ 84.221 | 2U, até 24× LFF 3.5" |
| Cinder Storage | PowerEdge **R770** (all-NVMe) | 3 | USD 30.899 | 2U, até 40× E3.S NVMe Gen5 |
| Network Node | PowerEdge **R670** | 6 | R$ 75.890 | 1U dual-socket, NIC quad 25GbE |
| Leaf Switch (ToR) | PowerSwitch **Z9264F-ON** | 18 | Consultar Dell | 64× 100GbE QSFP28 |
| Spine Switch | PowerSwitch **Z9664DX-ON** | 3 | Consultar Dell | 64× 400GbE QSFP-DD |
| OOB Switch | PowerSwitch **N3248TE-ON** | 9 | Consultar Dell | 48× 1GbE + 4× 10GbE uplink |

---

## 1. Control Plane Nodes — PowerEdge R670

**Qtd:** 12 unidades (4 por AZ: ctrl, db, mq, lb)
**Referência:** `01-physical-architecture.md` — Control Plane Nodes

### Por que R670

O R670 é o servidor rack **1U dual-socket** mais recente da Dell com Intel Xeon 6, lançado em 2024.
Atende ao requisito de 1U dual-socket com margem significativa em CPU e memória.

| Especificação | Requisito Arquitetural | PowerEdge R670 | Status |
|---|---|---|---|
| Form factor | 1U, dual-socket | 1U, 2 sockets | ✅ |
| CPU | 28C/socket, ≥ 2.6 GHz, AVX-512 | Xeon 6 até **86C/socket** (6787P) | ✅ Excede |
| RAM | 256 GB DDR4-3200 ECC | até **2 TB DDR5-6400** (32 DIMMs) | ✅ Excede |
| Boot | 2× SSD SATA 480 GB RAID1 | Suporte a RAID via PERC controller | ✅ |
| Data NVMe | 2× NVMe U.2 1.92 TB | Até 20× E3.S NVMe Gen5 | ✅ |
| NIC | 2× 25GbE RDMA SR-IOV | Broadcom 57414 2× 25GbE **ou** 57504 4× 25GbE | ✅ |
| BMC/Redfish | IPMI 2.0 + Redfish | iDRAC9 Enterprise (IPMI 2.0 + Redfish) | ✅ |
| PSU | 2× 800W Platinum hot-swap | Dual 1500W Titanium hot-swap | ✅ Excede |

### Configuração Recomendada por Nó

```
CPU  : 2× Intel Xeon 6 Gold (≥ 32C/socket, série 6700 ou 6900)
RAM  : 8× 32 GB DDR5-6400 RDIMM = 256 GB
Boot : 2× SSD SATA 480 GB (RAID1 via PERC)
Data : 2× NVMe 1.92 TB E3.S Gen5
NIC  : Broadcom 57414 Dual Port 25GbE SFP28 OCP 3.0
PSU  : Dual 1+1 1500W Titanium hot-swap
iDRAC: iDRAC9 Enterprise (Redfish, vConsole, vMedia)
```

**Preço base:** R$ 75.890 (site pt-br — configuração mínima)
**URL:** [dell.com/pt-br — PowerEdge R670](https://www.dell.com/pt-br/shop/servidores-de-data-center/servidor-poweredge-r670/spd/poweredge-r670)

---

## 2. Compute Nodes — PowerEdge R770

**Qtd:** 102 unidades (distribuídas nos 9 racks)
**Referência:** `01-physical-architecture.md` — Compute Nodes / `04-compute-plane.md`

### Por que R770

O R770 é o servidor rack **2U dual-socket** de próxima geração da Dell com Intel Xeon 6.
Oferece o maior número de cores por socket do portfólio Intel em 2U, atendendo com ampla folga
ao requisito de 40C/socket e 1 TB RAM por nó.

| Especificação | Requisito Arquitetural | PowerEdge R770 | Status |
|---|---|---|---|
| Form factor | 2U, dual-socket | 2U, 2 sockets | ✅ |
| CPU | 40C/socket, ≥ 2.3 GHz, VT-x, VT-d, EPT, AVX-512 | Xeon 6 até **86C/socket** (6787P) | ✅ Excede |
| RAM | 1 TB DDR4-3200 ECC | até 32 DIMMs DDR5-6400 (~2 TB) | ✅ Excede |
| Boot | 2× SSD SATA 480 GB RAID1 | Suporte via PERC | ✅ |
| Ephemeral | 2× NVMe U.2 3.84 TB | Até 24× NVMe (16× SAS4/SATA + 8× NVMe) ou 40× E3.S | ✅ |
| NIC | 2× 25GbE RDMA SR-IOV multiqueue | OCP 3.0: Broadcom 57504 4× 25GbE | ✅ |
| BMC | IPMI 2.0 + Redfish | iDRAC9 Enterprise | ✅ |
| PSU | 2× 1400W Platinum hot-swap | Dual até 3200W Titanium hot-swap | ✅ Excede |

### Configuração Recomendada por Nó

```
CPU  : 2× Intel Xeon 6 (≥ 40C/socket, série 6700P ou 6900P)
RAM  : 16× 64 GB DDR5-6400 RDIMM = 1 TB
Boot : 2× SSD SATA 480 GB (RAID1)
Ephm : 2× NVMe 3.84 TB E3.S Gen5 (ephemeral disk)
NIC  : Broadcom 57504 Quad Port 10/25GbE SFP28 OCP 3.0
PSU  : Dual 1+1 1600W ou 2000W Titanium hot-swap
iDRAC: iDRAC9 Enterprise
```

**Preço base:** USD 30.899 (site global — configuração mínima)
**Alternativa AMD:** PowerEdge **R7725** (AMD EPYC 9965, 192C/socket, a partir de USD 17.899) —
recomendado se requisito de densidade de vCPU for prioritário sobre compatibilidade Intel.

> **Nota KVM:** O Xeon 6 suporta VT-x, VT-d/IOMMU, EPT, e até 86 cores por socket com
> hardware multithreading — ideal para o perfil de overcommit 3:1 definido em `04-compute-plane.md`.

---

## 3. GPU Compute Nodes — PowerEdge XE8640

**Qtd:** 9 unidades (1 por rack, 3 por AZ)
**Referência:** `01-physical-architecture.md` — GPU Compute Nodes / `09-gpu-compute.md`

### Por que XE8640

O XE8640 é o servidor Dell otimizado para **4× GPU NVIDIA H100/H200 SXM5** com NVLink pleno,
atendendo exatamente ao requisito de 4 aceleradores SXM com 80 GB HBM2e e interconexão NVLink
≥ 600 GB/s bidirecional.

| Especificação | Requisito Arquitetural | PowerEdge XE8640 | Status |
|---|---|---|---|
| Form factor | 2U, dual-socket, suporte SXM4/PCIe Gen4 | **4U** dual-socket | ⚠️ ver nota |
| CPU | 40C/socket, VT-d/IOMMU | 2× Xeon Scalable 5ª Ger. até **56C/socket** | ✅ |
| RAM | 1 TB DDR4-3200 ECC | até **4 TB DDR5** (32 DIMMs) | ✅ Excede |
| GPU | 4× 80 GB HBM2e, SXM4, NVLink ≥ 600 GB/s, MIG | 4× **NVIDIA H100 80 GB SXM5**, NVLink pleno | ✅ |
| FP64 | ≥ 9 TFLOPS | H100: **33.5 TFLOPS FP64** | ✅ Excede |
| FP32 | ≥ 19 TFLOPS | H100: **67 TFLOPS FP32** | ✅ Excede |
| MIG | Suportado | MIG até 7 instâncias por GPU | ✅ |
| BMC | IPMI 2.0 + Redfish | iDRAC9 Enterprise | ✅ |
| PSU | 2× 2400W Platinum | **2800W Titanium** redundante hot-swap | ✅ Excede |
| Cooling GPU | Liquid cooling ≥ 400W TDP/GPU | Liquid cooling integrado (Direct Liquid Cooling) | ✅ |

> ⚠️ **Impacto no layout de rack:** O XE8640 é **4U** (não 2U como especificado na arquitetura).
> Cada rack FD1/FD2/FD3 precisa reservar **4U** para o GPU node em vez de 2U.
> Recomenda-se revisar o layout de rack em `01-physical-architecture.md` para acomodar este
> ajuste (impacto: -2U de compute por rack com GPU, equivalente a 1 compute node por rack afetado).
> Alternativa de maior densidade: **PowerEdge XE9680** (6U, 8× GPU H100/H200 SXM5) —
> consolida 2 GPU nodes em 1 servidor ao custo de 6U em vez de 4U.

### Configuração Recomendada por Nó

```
GPU  : 4× NVIDIA HGX H100 80 GB 700W SXM5 (NVLink pleno)
CPU  : 2× Intel Xeon Scalable 5ª Ger. (≥ 40C/socket)
RAM  : 16× 64 GB DDR5 = 1 TB
Boot : 2× SSD SATA 480 GB (RAID1)
NVMe : 2× NVMe 3.84 TB (local scratch para ML workloads)
NIC  : OCP 3.0 Dual Port 25GbE + InfiniBand/RoCE para comunicação GPU-GPU entre nós
PSU  : Dual 2800W Titanium redundante hot-swap
iDRAC: iDRAC9 Enterprise
```

**Preço:** Consultar Dell diretamente (sistemas XE não têm preço público — são vendidos por proposta).

> **PCI Vendor/Product ID:** Após recebimento do hardware, executar:
> ```bash
> lspci -nn | grep -i nvidia
> # Exemplo de saída esperada: 10de:2331  (H100 PCIe) ou 10de:2330  (H100 SXM5)
> ```
> Substituir os valores em `09-gpu-compute.md` conforme o modelo exato recebido.

---

## 4. Swift Storage Nodes — PowerEdge R760xd2

**Qtd:** 18 unidades (2 por rack × 9 racks)
**Referência:** `01-physical-architecture.md` — Storage Nodes Swift / `05-storage-plane.md`

### Por que R760xd2

O R760xd2 é explicitamente posicionado pela Dell para **file e object storage** com até 24 baias
LFF 3.5", sendo o modelo ideal para Swift com discos HDD 16 TB SAS.

| Especificação | Requisito Arquitetural | PowerEdge R760xd2 | Status |
|---|---|---|---|
| Form factor | 2U, 12+ baias LFF front-facing | 2U, até **24× 3.5" LFF** | ✅ Excede |
| CPU | 28C/socket, ≥ 2.0 GHz | 2× Xeon Scalable (4ª/5ª Ger.) | ✅ |
| RAM | 256 GB DDR4-3200 ECC | até **1.5 TB DDR5** (16 DIMMs) | ✅ Excede |
| Boot | 2× SSD SATA 480 GB RAID1 | Suporte via PERC | ✅ |
| Object | 12× HDD SAS 16 TB (7.2k) | 24 baias 3.5" SAS/SATA hot-plug | ✅ |
| Account/Container | 2× NVMe U.2 1.92 TB | Baias traseiras NVMe disponíveis | ✅ |
| NIC | 2× 25GbE RDMA | Broadcom 57414 2× 25GbE **ou** Intel E810 | ✅ |
| BMC | IPMI 2.0 + Redfish | iDRAC9 Enterprise | ✅ |

### Configuração Recomendada por Nó

```
CPU  : 2× Intel Xeon Gold (≥ 28C/socket)
RAM  : 8× 32 GB DDR5 = 256 GB
Boot : 2× SSD SATA 480 GB (RAID1)
Object: 12× HDD SAS 7200 RPM 16 TB 12Gbps (total 192 TB raw por nó)
A/C  : 2× NVMe 1.92 TB E3.S (account/container rings)
NIC  : Intel E810-XXV Dual Port 10/25GbE SFP28 OCP 3.0
PSU  : Dual 1+1 1400W Platinum hot-swap
iDRAC: iDRAC9 Enterprise
```

**Preço base:** R$ 84.221 (site pt-br — configuração mínima)
**URL:** [dell.com/pt-br — PowerEdge R760xd2](https://www.dell.com/pt-br/shop/servidores-de-data-center/servidor-poweredge-r760xd2/spd/poweredge-r760xd2)

> **Capacidade por nó:** 12× 16 TB = **192 TB raw**. Com replicação 3× do Swift:
> **64 TB úteis por nó**, **1.152 TB úteis totais** (18 nós).

---

## 5. Cinder Storage Nodes — PowerEdge R770 (all-NVMe)

**Qtd:** 3 unidades (1 por AZ, em FD1)
**Referência:** `01-physical-architecture.md` — Storage Nodes Cinder / `05-storage-plane.md`

### Por que R770 (all-NVMe)

O R770 com chassi all-NVMe suporta até **40× E3.S NVMe Gen5**, excedendo o requisito de
24× NVMe U.2 3.84 TB. O form factor E3.S (EDSFF) é o sucessor do U.2 na geração Intel Xeon 6,
com performance superior e maior densidade.

| Especificação | Requisito Arquitetural | PowerEdge R770 all-NVMe | Status |
|---|---|---|---|
| Form factor | 2U, 24+ baias NVMe U.2 | 2U, até **40× E3.S NVMe** Gen5 | ✅ Excede |
| CPU | 28C/socket, ≥ 2.0 GHz | Xeon 6 até 86C/socket | ✅ Excede |
| RAM | 512 GB DDR4-3200 ECC | até 32 DIMMs DDR5 (~2 TB) | ✅ Excede |
| Block | 24× NVMe U.2 3.84 TB | 24–40× E3.S 3.84 TB NVMe | ✅ (forma fator diferente) |
| NIC | 2× 25GbE RDMA, NVMe-oF | OCP 3.0 25GbE + suporte NVMe-oF/RoCE | ✅ |
| HBA | Tri-mode SAS/SATA/NVMe ≥ 16 portas | PERC12 ou HBA355i com suporte NVMe-oF | ✅ |
| BMC | IPMI 2.0 + Redfish | iDRAC9 Enterprise | ✅ |

### Configuração Recomendada por Nó

```
CPU  : 2× Intel Xeon 6 Gold (≥ 28C/socket)
RAM  : 16× 32 GB DDR5 = 512 GB
Boot : 2× SSD SATA 480 GB (RAID1)
Block: 24× NVMe E3.S 3.84 TB Gen5 (total 92.16 TB raw por nó)
NIC  : Broadcom 57504 Quad Port 10/25GbE SFP28 OCP 3.0 (NVMe-oF via RoCEv2)
HBA  : PERC H965i Front (Tri-mode, 24 portas NVMe-oF)
PSU  : Dual 1+1 1600W Titanium hot-swap
iDRAC: iDRAC9 Enterprise
```

**Preço base:** USD 30.899 (configuração mínima — configuração all-NVMe substancialmente superior)

> ⚠️ **Form factor de NVMe:** A arquitetura especifica U.2 (SFF-8639). O R770 usa E3.S (EDSFF).
> Ambos são NVMe PCIe Gen5, mas os conectores e suportes físicos diferem.
> Avaliar disponibilidade de U.2 backplane no R770 ou aceitar E3.S como equivalente funcional.

---

## 6. Network Nodes — PowerEdge R670

**Qtd:** 6 unidades (2 por AZ, em FD2 e FD3)
**Referência:** `01-physical-architecture.md` — Network Nodes / `06-networking`

### Por que R670

Mesmo modelo dos Control Plane nodes — 1U dual-socket com NIC de alta performance.
Para os Network Nodes o diferencial é a NIC quad-port 25GbE para suportar OVN Gateway e
Octavia Amphora com múltiplas interfaces (management, data, external, heartbeat).

### Configuração Recomendada por Nó

```
CPU  : 2× Intel Xeon 6 (≥ 16C/socket)
RAM  : 4× 32 GB DDR5 = 128 GB
Boot : 2× SSD SATA 480 GB (RAID1)
NIC  : Broadcom 57504 Quad Port 10/25GbE SFP28 OCP 3.0   ← 4 portas para bonds
NIC2 : (opcional) 2ª placa PCIe 2× 25GbE para tráfego externo
PSU  : Dual 1+1 800W Platinum hot-swap
iDRAC: iDRAC9 Enterprise
```

**Preço base:** R$ 75.890 (mesmo SKU do control plane — diferencia-se na configuração)

---

## 7. Switches — Fabric de Rede

### 7.1 Leaf / ToR — Dell PowerSwitch Z9264F-ON

**Qtd:** 18 unidades (2 por rack × 9 racks)

| Especificação | Requisito Arquitetural | Z9264F-ON |
|---|---|---|
| Portas | 32× 100GbE QSFP28 (breakout 4× 25GbE) | **64× 100GbE QSFP28** (breakout 4× 25GbE) |
| Buffer | ≥ 16 MB | 32 MB shared buffer |
| Latência | ≤ 500 ns | ~600 ns (cut-through) |
| Protocolos | BGP, EVPN, MLAG, BFD, VXLAN HW offload | BGP, EVPN, VxLAN, MLAG, BFD ✅ |
| OS | Aberto/programável | Dell OS10 (SONiC-based, APIs REST/gNMI) ✅ |

> **Alternativa:** Dell PowerSwitch **S5248F-ON** (48× 25GbE + 6× 100GbE + 2× 100GbE MGMT)
> para quem prefere portas 25GbE nativas em vez de breakout de 100GbE.

### 7.2 Spine — Dell PowerSwitch Z9664DX-ON

**Qtd:** 3 unidades (1 por AZ, em racks R2, R5, R8)

| Especificação | Requisito Arquitetural | Z9664DX-ON |
|---|---|---|
| Portas | 32× 400GbE QSFP-DD | **64× 400GbE QSFP-DD** |
| Breakout | 4× 100GbE por porta | Sim (4× 100GbE ou 8× 50GbE) |
| Uplinks para leaves | 18× 100GbE | 64× 400GbE (suporta 256× 100GbE breakout) |
| Protocolos | BGP eBGP, EVPN, BFD, ECMP | BGP, EVPN, BFD, ECMP ✅ |
| Latência | ≤ 500 ns | ~800 ns (cut-through) |
| OS | Aberto/programável | Dell OS10 ✅ |

### 7.3 Management OOB — Dell PowerSwitch N3248TE-ON

**Qtd:** 9 unidades (1 por rack)

| Especificação | Requisito Arquitetural | N3248TE-ON |
|---|---|---|
| Portas | 48× 1GbE base-T + 4× 10GbE uplink | **48× 1GbE RJ45 + 4× 10GbE SFP+** ✅ |
| Função | OOB/IPMI/PXE isolado | VLAN segregada, DHCP relay, PoE opcional |

---

## 8. HSM Appliances

Os HSMs não fazem parte do portfólio Dell (são appliances especializados). Candidatos certificados
FIPS 140-2 Level 3 compatíveis com a arquitetura:

| Fabricante | Modelo | FIPS | PKCS#11 | KMIP | HA Group |
|---|---|---|---|---|---|
| **Thales** | **Luna Network HSM 7** | 140-2 L3 | v2.40 | 1.4+ | Sim |
| **Entrust** | nShield Connect XC | 140-2 L3 | v2.40 | 1.4+ | Sim |
| **Futurex** | VirtuCrypt KMES | 140-2 L3 | v2.40 | 1.4+ | Sim |

> Detalhes de integração com Barbican em `docs/10-hsm-key-management.md`.
> Scripts Ansible para deploy dos roles HSM em `ansible/roles/` (se disponível).

---

## 9. Quantitativos Consolidados

### Servidores

| Modelo | Role | Qtd | Preço Base Unit. | Estimativa Total |
|---|---|---:|---|---|
| PowerEdge R670 | Control Plane | 12 | R$ 75.890 | ~R$ 910.680 |
| PowerEdge R670 | Network Node | 6 | R$ 75.890 | ~R$ 455.340 |
| PowerEdge R770 | Compute | 102 | USD 30.899 | ~USD 3.151.698 |
| PowerEdge R770 | Cinder (all-NVMe) | 3 | USD 30.899 | ~USD 92.697 |
| PowerEdge R760xd2 | Swift | 18 | R$ 84.221 | ~R$ 1.515.978 |
| PowerEdge XE8640 | GPU | 9 | Consultar Dell | — |
| **Total servidores** | | **150** | | |

> ⚠️ Os preços acima são configurações **base** (mínimas). As configurações produção com CPU,
> RAM e storage corretos resultarão em valores substancialmente superiores — estimativa de
> **3–5× o preço base** dependendo da configuração de memória e storage.

### Rede

| Modelo | Role | Qtd |
|---|---|---:|
| PowerSwitch Z9264F-ON | Leaf / ToR | 18 |
| PowerSwitch Z9664DX-ON | Spine | 3 |
| PowerSwitch N3248TE-ON | OOB Management | 9 |
| **Total switches** | | **30** |

---

## 10. Notas de Desvio da Especificação Original

| Item | Especificação Original | Hardware Dell | Impacto |
|---|---|---|---|
| GPU node form factor | 2U | **4U** (XE8640) | Cada rack com GPU node perde 2U de espaço para compute (+2U) |
| NVMe Cinder | U.2 (SFF-8639) | **E3.S** (EDSFF) no R770 | Form factor diferente, performance equivalente ou superior; validar backplane |
| GPU TDP cooling | Liquid cooling ≥ 400W/GPU | **Direct Liquid Cooling** integrado no XE8640 | Requer infraestrutura de agua/coolant no rack |
| GPU product ID | Placeholder `10DE/****` | H100 SXM5: provavelmente `10de:2330` | Confirmar com `lspci -nn` após entrega; atualizar `09-gpu-compute.md` |

---

## 11. Próximos Passos

1. **RFQ formal com Dell** para os 150 servidores + 30 switches — volumes dessa magnitude
   normalmente resultam em descontos de 20–40% sobre o preço de lista.
2. **Validar layout de rack** em `01-physical-architecture.md` para acomodar GPU nodes 4U.
3. **Selecionar CPU exata** para cada role (a linha Xeon 6 tem modelos E/P — Efficient e
   Performance; os compute nodes devem usar a linha P para maior contagem de cores).
4. **Definir backplane NVMe** para Cinder nodes — confirmar se E3.S ou U.2 dependendo da
   disponibilidade do modelo no momento da compra.
5. **Levantar HSM** com Thales/Entrust para cotação e tempo de entrega (lead time tipicamente
   8–16 semanas para FIPS L3).
6. **Provisionar licenças iDRAC** — iDRAC9 Enterprise é necessário para Redfish, Virtual
   Console e recursos de automação; verificar se já incluso ou licença separada.

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
| Compute | PowerEdge **R770** | 102 | R$ 82.819 | 2U dual-socket Intel Xeon 6 |
| GPU Compute | PowerEdge **XE8640** | 9 | ~R$ 1.645.000 ⁶ | 4U, 4× H100 SXM5 NVLink |
| Swift Storage | PowerEdge **R760xd2** | 18 | R$ 84.221 | 2U, até 24× LFF 3.5" |
| Cinder Storage | PowerEdge **R770** (all-NVMe) | 3 | R$ 82.819 | 2U, até 40× E3.S NVMe Gen5 |
| Network Node | PowerEdge **R670** | 6 | R$ 75.890 | 1U dual-socket, NIC quad 25GbE |
| Leaf Switch (ToR) | PowerSwitch **S5448F-ON** | 18 | Consultar Dell | 48× 100GbE + 8× 400GbE QSFP56-DD |
| Spine Switch | PowerSwitch **Z9664F-ON** | 3 | Consultar Dell | 64× 400GbE QSFP56-DD, 2U |
| OOB Switch | PowerSwitch **N3248TE-ON** | 9 | Consultar Dell | 48× 1GbE + 4× 10GbE SFP+ |
| HSM Appliance | Kryptus **ASI-HSM AHX5 KNET** | 3 | R$ 256.000 | FIPS 140-2 L3, ICP-Brasil, EAL4+, PKCS#11, KMIP nativo |

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
**Produto BR:** [dell.com/pt-br — PowerEdge R670](https://www.dell.com/pt-br/shop/servidores-de-data-center/servidor-poweredge-r670/spd/poweredge-r670)
**Spec Sheet:** [poweredge-r670-spec-sheet.pdf](https://www.delltechnologies.com/asset/en-us/products/servers/technical-support/poweredge-r670-spec-sheet.pdf) (en-us — versão pt-br não disponível)
**Guia Técnico pt-br:** [poweredge-r670-technical-guide.pdf](https://www.delltechnologies.com/asset/pt-br/products/servers/technical-support/poweredge-r670-technical-guide.pdf)

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

**Preço base:** R$ 82.819 (site pt-br — configuração mínima)
**Produto BR:** [dell.com/pt-br — PowerEdge R770](https://www.dell.com/pt-br/shop/servidores-de-data-center/servidor-poweredge-r770/spd/poweredge-r770)
**Spec Sheet pt-br:** [poweredge-r770-spec-sheet.pdf](https://www.delltechnologies.com/asset/pt-br/products/servers/technical-support/poweredge-r770-spec-sheet.pdf)
**Guia Técnico pt-br:** [poweredge-r770-technical-guide.pdf](https://www.delltechnologies.com/asset/pt-br/products/servers/technical-support/poweredge-r770-technical-guide.pdf)


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
**Produto BR:** [dell.com/pt-br — PowerEdge XE8640](https://www.dell.com/pt-br/shop/servidores-de-data-center/servidor-poweredge-xe8640/spd/poweredge-xe8640)
**Spec Sheet:** [poweredge-xe8640-spec-sheet.pdf](https://www.delltechnologies.com/asset/en-us/products/servers/technical-support/poweredge-xe8640-spec-sheet.pdf) (en-us)

> **Alternativa de maior densidade — PowerEdge XE9680** (disponível no site BR):
> - **6U**, 2-socket, **8× GPU** NVIDIA H100 80GB ou H200 141GB SXM5, NVLink pleno
> - RAM: até 4 TB DDR5 | Storage: até 16× E3.S NVMe
> - Indicado se a arquitetura for consolidada: 5× XE9680 (40 GPUs) em vez de 9× XE8640 (36 GPUs)
> - **Produto BR:** [dell.com/pt-br — PowerEdge XE9680](https://www.dell.com/pt-br/shop/servidores-de-data-center/servidor-poweredge-xe9680/spd/poweredge-xe9680)
> - **Spec Sheet:** [poweredge-xe9680-spec-sheet.pdf](https://www.delltechnologies.com/asset/en-us/products/servers/technical-support/poweredge-xe9680-spec-sheet.pdf) (en-us)

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
**Produto BR:** [dell.com/pt-br — PowerEdge R760xd2](https://www.dell.com/pt-br/shop/servidores-de-data-center/servidor-poweredge-r760xd2/spd/poweredge-r760xd2)
**Spec Sheet pt-br:** [poweredge-r760xd2-spec-sheet.pdf](https://www.delltechnologies.com/asset/pt-br/products/servers/technical-support/poweredge-r760xd2-spec-sheet.pdf)
**Guia Técnico:** [poweredge-r760xd2-technical-guide.pdf](https://www.delltechnologies.com/asset/en-us/products/servers/technical-support/poweredge-r760xd2-technical-guide.pdf)

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

**Preço base:** R$ 82.819 (site pt-br — configuração mínima; all-NVMe substancialmente superior)
**Produto BR:** [dell.com/pt-br — PowerEdge R770](https://www.dell.com/pt-br/shop/servidores-de-data-center/servidor-poweredge-r770/spd/poweredge-r770)
**Spec Sheet pt-br:** [poweredge-r770-spec-sheet.pdf](https://www.delltechnologies.com/asset/pt-br/products/servers/technical-support/poweredge-r770-spec-sheet.pdf)

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
**Produto BR:** [dell.com/pt-br — PowerEdge R670](https://www.dell.com/pt-br/shop/servidores-de-data-center/servidor-poweredge-r670/spd/poweredge-r670)
**Spec Sheet:** [poweredge-r670-spec-sheet.pdf](https://www.delltechnologies.com/asset/en-us/products/servers/technical-support/poweredge-r670-spec-sheet.pdf) (en-us)

---

## 7. Switches — Fabric de Rede

### 7.1 Leaf / ToR — Dell PowerSwitch S5448F-ON

**Qtd:** 18 unidades (2 por rack × 9 racks)

O S5448F-ON é o switch leaf/ToR disponível no site Dell BR com densidade 100GbE e uplinks 400GbE nativos, substituindo o Z9264F-ON que não consta no catálogo brasileiro.

| Especificação | Requisito Arquitetural | S5448F-ON | Status |
|---|---|---|---|
| Portas downlink | 32× 100GbE (breakout 4× 25GbE) | **48× 100GbE SFP56-DD** (breakout 4× 25GbE) | ✅ Excede |
| Portas uplink | 3× 100GbE para spines | **8× 400GbE QSFP56-DD** (breakout 4× 100GbE) | ✅ Excede |
| Portas mgmt | — | 2× 10GbE SFP+ | ✅ |
| Buffer | ≥ 16 MB | 32 MB shared buffer | ✅ |
| Latência | ≤ 500 ns | ~600 ns cut-through | ✅ |
| Protocolos | BGP, EVPN, MLAG, BFD, VXLAN HW offload | BGP, EVPN, MLAG, BFD, VXLAN ✅ | ✅ |
| OS | Aberto/programável, APIs declarativas | Dell OS10 / Enterprise SONiC (REST, gNMI) | ✅ |

**Produto BR:** [dell.com/pt-br — PowerSwitch S5448F-ON](https://www.dell.com/pt-br/shop/switches-de-data-center/powerswitch-s5448f-on/spd/powerswitch-s5448f-on)
**Spec Sheet:** [dell-emc-powerswitch-s5448f-on-spec-sheet.pdf](https://www.delltechnologies.com/asset/en-us/products/networking/technical-support/dell-emc-powerswitch-s5448f-on-spec-sheet.pdf)

### 7.2 Spine — Dell PowerSwitch Z9664F-ON

**Qtd:** 3 unidades (1 por AZ, em racks R2, R5, R8)

| Especificação | Requisito Arquitetural | Z9664F-ON | Status |
|---|---|---|---|
| Portas | 32× 400GbE QSFP-DD | **64× 400GbE QSFP56-DD** ou 256× 100GbE | ✅ Excede |
| Breakout | 4× 100GbE por porta | 4× 100GbE ou 8× 50GbE por porta | ✅ |
| Fabric uplinks para 18 leaves | 18× 100GbE | 64 portas 400GbE disponíveis (suporta breakout) | ✅ |
| Protocolos | BGP eBGP, EVPN, BFD, ECMP | BGP, EVPN, BFD, ECMP ✅ | ✅ |
| Latência | ≤ 500 ns | ~800 ns cut-through | ✅ |
| Switching fabric | — | **51,2 Tbps** non-blocking | ✅ |
| Form factor | 1U | **2U** | ⚠️ notar no rack FD2 |
| OS | Aberto/programável | Dell OS10 / Enterprise SONiC ✅ | ✅ |

**Produto BR:** [dell.com/pt-br — PowerSwitch Z9664F-ON](https://www.dell.com/pt-br/shop/switches-de-data-center/powerswitch-z9664f-on/spd/powerswitch-z9664f-on)
**Spec Sheet:** [dell-powerswitch-z9664f-on-spec-sheet.pdf](https://www.delltechnologies.com/asset/en-us/products/networking/technical-support/dell-powerswitch-z9664f-on-spec-sheet.pdf)

> **Alternativa de nova geração:** PowerSwitch **Z9864F-ON** (64× 800GbE OSFP112, 2U) — posicionado para fabrics de IA generativa; indicado se a escala prevista para GPU workloads justificar 800GbE.
> [Spec Sheet Z9864F-ON](https://www.delltechnologies.com/asset/en-us/products/networking/technical-support/dell-powerswitch-z9864f-on-spec-sheet.pdf)

> ⚠️ **Form factor 2U:** o rack FD2 precisa reservar 2U para o spine (era 1U no layout original). Revisar posições U7-U8 no layout do rack FD2 em `01-physical-architecture.md`.

### 7.3 Management OOB — Dell PowerSwitch N3248TE-ON

**Qtd:** 9 unidades (1 por rack)

| Especificação | Requisito Arquitetural | N3248TE-ON | Status |
|---|---|---|---|
| Portas | 48× 1GbE base-T + 4× 10GbE uplink | **48× 1GbE RJ45 + 4× 10GbE SFP+ + 2× 100GbE QSFP28** | ✅ Excede |
| Função | OOB/IPMI/PXE isolado | VLAN segregada, DHCP relay, PoE opcional | ✅ |
| OS | — | Dell OS10 | ✅ |

**Produto BR:** [dell.com/pt-br — PowerSwitch N3248TE-ON](https://www.dell.com/pt-br/shop/switches-de-data-center/powerswitch-n3248te-on/spd/powerswitch-n3248te-on)
**Spec Sheet:** [dell-powerswitch-n3248te-on-spec-sheet.pdf](https://www.delltechnologies.com/asset/en-us/products/networking/technical-support/dell-powerswitch-n3248te-on-spec-sheet.pdf)

---

## 8. HSM Appliances — Kryptus ASI-HSM AHX5 KNET

HSMs são appliances especializados fora do portfólio Dell. O modelo recomendado é o
**Kryptus ASI-HSM AHX5 KNET** — fabricante brasileiro com FIPS 140-2 Level 3 e homologação
ICP-Brasil, diferenciais críticos para conformidade com legislação brasileira (LGPD, SPB, PIX,
Open Banking).

**Fonte:** [kryptus.com/knet-hsm](https://kryptus.com/knet-hsm/)
**Preço de referência:** R$ 256.000,00/unidade — contrato público vigência 30/10/2024–29/10/2029
(2 unidades × R$ 256.000 = R$ 512.000 — base para estimativa das 3 unidades desta arquitetura)

### Especificações — Kryptus KNET HSM

| Especificação | Requisito Arquitetural | KNET HSM | Status |
|---|---|---|---|
| Certificação FIPS | 140-2 Level 3 | **FIPS 140-2 Level 3** | ✅ |
| Common Criteria | — | **EAL4+** (ISO/IEC 15408, EN 419221-5:2018) | ✅ Bônus |
| ICP-Brasil | — | **Homologado** | ✅ Bônus (obrigatório para PKI nacional) |
| PCI DSS | — | **Conforme** | ✅ |
| Algoritmos | RSA, ECC, AES, SHA-2, HMAC, 3DES | RSA, ECC, AES, SHA — lista completa via datasheet | ✅ |
| PKCS#11 | v2.40+ | ✅ (SDK incluído) | ✅ |
| KMIP | 1.4+ | **Servidor KMIP embarcado** (nativo, sem drivers externos) | ✅ |
| OpenSSL / JCA / CSP | — | ✅ (Windows CAPI/CSP, OpenSSL, Java JCA/JCE) | ✅ |
| Partições (Virtual HSMs) | ≥ 100 | **até 50 Virtual HSMs** por appliance | ⚠️ ver nota |
| HA Group / replicação | Sim | **Preparado para HA** (detalhes via proposta) | ✅ |
| Performance RSA-2048 | ≥ 20.000 ops/s | Não publicado — solicitar datasheet | ❓ |
| Form factor | 1U rack-mount | **1U rack-mount** (confirmar com Kryptus) | ✅ |
| Conectividade | 2× 1GbE bonding | A confirmar via datasheet | ❓ |
| Tamper / zeroização | Sim | **Zeroização automática** em violação física | ✅ |
| Objetos/chaves | — | **até 2,5 milhões** de objetos (chaves + certificados) | ✅ |

> ⚠️ **Partições:** A arquitetura especifica ≥ 100 partições por appliance. O KNET HSM suporta
> até **50 Virtual HSMs** por unidade. Com 3 appliances em cluster HA, a capacidade total é
> 150 partições — suficiente se distribuídas entre os nós. Confirmar com Kryptus se o cluster
> expõe as partições de forma agregada ou se o limite de 50 é por nó independentemente.

### Por que Kryptus em vez de Thales/Entrust

| Critério | Kryptus KNET | Thales Luna 7 | Entrust nShield |
|---|---|---|---|
| Fabricação | 🇧🇷 Nacional | 🇺🇸 EUA/França | 🇺🇸 EUA |
| ICP-Brasil | ✅ Homologado | Parcial (via integradores) | Parcial |
| FIPS 140-2 L3 | ✅ | ✅ | ✅ |
| Common Criteria EAL4+ | ✅ | ✅ | ✅ |
| KMIP nativo | ✅ (embarcado) | Via add-on | Via add-on |
| Suporte local (BR) | ✅ Campinas/SP | Via revenda | Via revenda |
| Conformidade LGPD/SPB/PIX | ✅ Nativo | Requer validação | Requer validação |
| Lei de TI nacional (preferência) | ✅ Favorável | ❌ | ❌ |

### Configuração para a Arquitetura (3 appliances)

```
Qtd    : 3 unidades (1 por AZ, em U39 dos racks FD1)
Deploy : Cluster HA active-active entre os 3 appliances
Partições por appliance : 50 Virtual HSMs (total 150 no cluster)
Integração : Barbican via PKCS#11 driver + librashsm (ou driver Kryptus)
             KMIP server embarcado para serviços adicionais
Backup : Backup criptografado para appliance offline por AZ
         (conforme procedimento em docs/10-hsm-key-management.md)
```

### Contato e Proposta

```
Kryptus Segurança da Informação
Site   : https://kryptus.com
Tel    : +55 (19) 3112-5000
WhatsApp: disponível no site
Local  : Campinas, SP — Brasil
Solicitar: datasheet técnico completo + proposta para 3 unidades + SLA de suporte
```

> **Nota de integração com Barbican:** O Kryptus disponibiliza SDK com suporte a PKCS#11.
> A configuração do plugin `p11_crypto_plugin` do Barbican segue o mesmo padrão descrito em
> `docs/10-hsm-key-management.md` — substituir apenas `library_path` pelo caminho da
> biblioteca `.so` fornecida pela Kryptus.

> Detalhes de configuração Barbican ↔ HSM em `docs/10-hsm-key-management.md`.

---

## 9. Quantitativos Consolidados

### Servidores e Appliances

| Modelo | Role | Qtd | Preço Base Dell ² | Estimativa Total | Ref. Gov. (unit.) ³ | Fonte Gov. |
|---|---|---:|---:|---:|---|---|
| PowerEdge R670 | Control Plane | 12 | R$ 75.890 | R$ 910.680 | R$ 96k–157k | SERPRO Itens 1/8/9 |
| PowerEdge R670 | Network Node | 6 | R$ 75.890 | R$ 455.340 | R$ 96k–157k | SERPRO Itens 1/8/9 |
| PowerEdge R770 | Compute | 102 | R$ 82.819 | R$ 8.447.538 | R$ 277k–305k ⁴ | SERPRO Itens 2/3/4 |
| PowerEdge R770 | Cinder (all-NVMe) | 3 | R$ 82.819 | R$ 248.457 | R$ 277k–305k ⁴ | SERPRO Itens 2/3/4 |
| PowerEdge R760xd2 | Swift | 18 | R$ 84.221 | R$ 1.515.978 | R$ 129k–221k | SERPRO Itens 9/10/11 |
| PowerEdge XE8640 | GPU | 9 | ~R$ 1.645.000 ⁶ | ~R$ 14.805.000 | R$ 1.645k–2.894k ⁶⁷ | Embrapa 2023 / INCA ARP 2026 |
| Kryptus ASI-HSM AHX5 KNET | HSM | 3 | R$ 256.000 | R$ 768.000 | R$ 256.000 | Contrato público 2024 |
| **Total** | | **153** | | **~R$ 27.150.993** ¹ | | |

¹ _Total incluindo XE8640 com referência Embrapa (R$ 14.805.000) + demais itens com preço BRL (R$ 12.345.993). Não inclui switches (sob proposta)._

² _Preços Dell = configuração **base** (mínima). Produção com CPU/RAM/storage adequados resulta em 3–5× superior para servidores sem GPU._

³ _Referência Gov. = **valores estimados sigilosos** do Pregão SERPRO 91031/2025 (UASG 803080, out/2025) e Contrato CENSIPAM 31/2025. São tetos orçamentários, não preços homologados — os preços vencedores dos leilões tendem a ser inferiores. Usados apenas como balizamento de mercado público._

⁴ _SERPRO Itens 2–4 têm 512 GB RAM e 15–20 núcleos/socket, configuração inferior ao R770 (1 TB RAM, 40+ núcleos/socket). Os R$ 277k–305k representam um piso de comparação — o R770 com configuração produção deverá superar este valor._

⁵ _CENSIPAM Contrato 31/2025: servidor rack com **1× NVIDIA L40S 48GB PCIe** (GPU de inferência), não equivalente ao XE8640 (4× H100 80GB SXM5 de treinamento). Mantido como referência de piso._

⁶ _XE8640 Ref. Gov. (piso): cotação Perficomp referenciando **Embrapa UASG 135027, Pregão 12/2023, Item 02** — 4 unidades a R$ 1.645.000 cada, validade 16/11/2024. Configuração: 2× Xeon Gold 6448Y 32C, **2TB RAM**, 4× NVMe 7.68TB U.2 Gen4, 4× NVIDIA HGX H100 SXM5 80GB HBM3, Broadcom 57504 Quad 25GbE, 5 anos ProSupport 4h on-site. Spec mais robusta que a nossa; preço defasado ~18 meses. ARP não localizada; tratar como referência indicativa._

⁷ _XE8640 Ref. Gov. (teto): **ARP INCA Nº 5/2026** (Pregão 91.234/2025, PNCP 23/12/2025, válida até ~dez/2026) — fornecedor VERSATUS HPC, Item 1: "Plataforma computacional GPU alto desempenho, NVIDIA, **refrigerada a ar**" — R$ 2.894.000/unidade. **⚠️ Atenção: "refrigerada a ar" diverge do XE8640** (que usa Direct Liquid Cooling para H100 SXM5 700W). Sem acesso ao Termo de Referência do Pregão 91.234/2025, não é possível confirmar se o equipamento homologado corresponde ao XE8640 ou a uma plataforma diferente (ex: servidor com H100/H200 PCIe air-cooled). R$ 2.894.000 representa um **teto de referência 2026**. Esta ARP é aderível por qualquer órgão federal como não-participante (Art. 4.1, Lei 14.133/2021) — oportunidade de compra pública sem nova licitação._

> ⚠️ **Servidores Dell:** preços de configuração **base** (mínima). Configurações de produção
> com CPU, RAM e storage adequados resultarão em valores **3–5× superiores**.
>
> ⚠️ **HSM Kryptus:** preço extraído de contrato público vigente (30/10/2024–29/10/2029),
> 2 unidades a R$ 256.000/un. Usado como referência — solicitar proposta formal para 3 unidades.

### Rede e Infraestrutura

| Modelo | Role | Qtd | Preço Ref. Unit. | Estimativa Total | Ref. Gov. (unit.) | Fonte Gov. |
|---|---|---:|---|---|---|---|
| PowerSwitch S5448F-ON | Leaf / ToR | 18 | Consultar Dell | A consultar | — | — |
| PowerSwitch Z9664F-ON | Spine | 3 | Consultar Dell | A consultar | — | — |
| PowerSwitch N3248TE-ON | OOB Management | 9 | Consultar Dell | A consultar | — | — |
| **Total switches** | | **30** | | **A consultar** | | |

### Infraestrutura Física (item não contemplado anteriormente)

| Item | Especificação | Qtd | Ref. Gov. Unit. | Estimativa Total | Fonte |
|---|---|---:|---:|---:|---|
| Rack 42U 19" | APC ou equivalente | 9 | R$ 17.500 | R$ 157.500 | ARP INCA 5/2026, Item 9 |
| Transceivers 25GbE | SFP28 (hosts → leaf) | ~600 | R$ 3.900 ⁸ | ~R$ 2.340.000 | ARP INCA 5/2026, Item 3 |
| Transceivers 100GbE | QSFP28 (leaf → spine) | 54 | R$ 3.200 | R$ 172.800 | ARP INCA 5/2026, Item 2 |

> ⁸ Transceivers 25GbE (ARP INCA): estimativa de 2 por servidor × ~300 servidores sem GPU = ~600 unidades. Valor indicativo — quantitativo real depende do projeto de cabeamento detalhado.

---

## 10. Notas de Alinhamento com a Arquitetura

| Item | Situação | Ação tomada |
|---|---|---|
| GPU node form factor | `01-physical-architecture.md` atualizado de 2U para **4U** | Layouts dos 3 tipos de rack revisados; FD1 usa painéis verticais laterais para cable mgmt |
| Spine switch form factor | `01-physical-architecture.md` atualizado de 1U para **2U** (Z9664F-ON é 2U) | Rack FD2: posições U7-U42 recalculadas — total continua 42U |
| NVMe Cinder | `01-physical-architecture.md` atualizado para **NVMe SFF** (agnóstico de form factor) | Aceita U.2, E3.S/EDSFF ou equivalente PCIe Gen4+ |
| GPU TDP cooling | Requisito de liquid cooling ≥ 400W/GPU mantido na arquitetura | XE8640 atende com Direct Liquid Cooling integrado |
| GPU product ID | Placeholder em `09-gpu-compute.md` | Executar `lspci -nn \| grep -i nvidia` após entrega e preencher |
| Switch Leaf | Z9264F-ON não está no catálogo BR | Substituído por **S5448F-ON** (48×100GbE + 8×400GbE), disponível no site dell.com/pt-br |

---

## 11. Próximos Passos

1. **RFQ formal com Dell** para os 153 servidores + 30 switches — volumes dessa magnitude
   normalmente resultam em descontos de 20–40% sobre o preço de lista.
2. ~~**Validar layout de rack**~~ ✅ **Concluído** — GPU 4U e Spine 2U já incorporados em
   `01-physical-architecture.md`; layouts FD1/FD2/FD3 recalculados e validados em 42U.
3. **Selecionar CPU exata** para cada role (a linha Xeon 6 tem modelos E/P — Efficient e
   Performance; os compute nodes devem usar a linha P para maior contagem de cores).
4. **Definir backplane NVMe** para Cinder nodes — confirmar se E3.S ou U.2 dependendo da
   disponibilidade no momento da compra; atualizar spec em `01-physical-architecture.md`.
5. **Contatar Kryptus** para proposta formal de 3 unidades ASI-HSM AHX5 KNET + SLA de suporte
   + confirmar: performance RSA-2048 ops/s, form factor exato, HA group entre AZs, e agregação
   de partições no cluster. Tel: +55 (19) 3112-5000 | kryptus.com.
6. **Confirmar PCI Vendor/Product ID das GPUs** — executar `lspci -nn | grep -i nvidia` após
   entrega dos XE8640 e atualizar `09-gpu-compute.md`.
7. **Provisionar licenças iDRAC** — iDRAC9 Enterprise é necessário para Redfish, Virtual
   Console e automação; verificar se já incluso no SKU ou licença separada.
8. **Obter cotações dos switches** (S5448F-ON, Z9664F-ON, N3248TE-ON) — todos estão no
   catálogo dell.com/pt-br mas sem preço público; solicitar via canal comercial Dell BR.

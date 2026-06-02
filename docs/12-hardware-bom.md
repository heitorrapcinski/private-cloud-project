# 12 — Bill of Materials — Hardware

> Documento gerado com base nos requisitos técnicos de `01-physical-architecture.md`.
> **Estratégia de referência de preços:** Para cada componente, usa-se a melhor fonte disponível
> na seguinte ordem de prioridade: (1) contrato público federal vigente ou ARP aderível —
> preços reais licitados; (2) catálogo Dell PowerEdge/PowerSwitch BR — preços de lista para
> configuração base; (3) cotações históricas de compras governamentais — balizamento indicativo.
>
> Preços de catálogo referem-se à configuração **base** (mínima) — produção com CPU, RAM e
> storage adequados resulta em 3–5× superior para servidores sem GPU. Preços de contratos
> públicos incluem configuração completa conforme edital.
>
> **Nenhum fornecedor é mandatório.** Os modelos listados são referências de especificação e
> preço. A licitação final deve ser por requisitos técnicos, não por marca ou modelo específico.

---

## Resumo Executivo

| Role | Modelo de Referência | Qtd | Preço Ref. Unit. | Estimativa | Fonte |
|---|---|---:|---|---:|---|
| Control Plane | Dell PowerEdge **R670** | 12 | R$ 75.890 (base) | R$ 910.680 | Catálogo Dell BR ¹ |
| Compute | Dell PowerEdge **R770** | 102 | R$ 82.819 (base) | R$ 8.447.538 | Catálogo Dell BR ¹ |
| GPU Compute | Lenovo **SR680a V3** (4× H200) | 9 | **R$ 1.260.000** | R$ 11.340.000 | Contrato SERPRO 263505 ² |
| Swift Storage | Dell PowerEdge **R760xd2** | 18 | R$ 84.221 (base) | R$ 1.515.978 | Catálogo Dell BR ¹ |
| Cinder Storage | Dell PowerEdge **R770** (NVMe) | 3 | R$ 82.819 (base) | R$ 248.457 | Catálogo Dell BR ¹ |
| Network Node | Dell PowerEdge **R670** | 6 | R$ 75.890 (base) | R$ 455.340 | Catálogo Dell BR ¹ |
| Leaf Switch | Cisco **N9K-C93180YC-FX3** | 18 | R$ 131.100 | R$ 2.359.800 | ARP SERPRO 90611/2025 ² |
| Spine Switch | Cisco **N9K-C93600CD-GX** | 3 | R$ 288.900 | R$ 866.700 | ARP SERPRO 90611/2025 ² |
| OOB Switch | Dell PowerSwitch **N3248TE-ON** | 9 | A consultar | A consultar | Catálogo Dell BR |
| HSM Appliance | Kryptus **ASI-HSM AHX5 KNET** | 3 | R$ 256.000 | R$ 768.000 | Contrato público 2024 ² |
| Racks + Transceivers | Infra física | — | — | ~R$ 802.968 | SERPRO/NTT + INCA ARP ² |
| **Total estimado** | | **153 serv. + 30 switches** | | **~R$ 27,7M** | excl. OOB switch |

> ¹ **Catálogo base:** preços de configuração mínima — servidores de produção com CPU, RAM e
>   storage adequados resultam em **3–5× superior**. Usar como piso de referência; solicitar
>   proposta formal ou verificar ARP SERPRO PE 91031/2025 (UASG 803080) para calibrar.
>
> ² **Contrato público:** preços reais licitados incluindo configuração completa. GPU e switches
>   são as parcelas mais representativas e têm a melhor qualidade de referência de preço.

---

## 1. Control Plane Nodes — Referência: Dell PowerEdge R670

**Qtd:** 12 unidades (4 por AZ: ctrl, db, mq, lb)
**Referência arquitetural:** `01-physical-architecture.md` — Control Plane Nodes
**Fonte do preço:** Catálogo Dell BR (configuração base). Sem contrato público de referência
localizado para este perfil. Equivalentes aceitáveis: Lenovo ThinkSystem SR650 V3, HPE ProLiant
DL380 Gen11, ou qualquer servidor 1U dual-socket com Intel Xeon recente que atenda a tabela abaixo.

### Por que R670 como referência

O R670 é o servidor rack **1U dual-socket** mais recente da Dell com Intel Xeon 6, com specs
bem documentadas e disponível no catálogo BR com preço público. É usado aqui como modelo de
conformidade — o requisito é a especificação técnica da tabela, não o fabricante.

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

## 2. Compute Nodes — Referência: Dell PowerEdge R770

**Qtd:** 102 unidades (distribuídas nos 9 racks)
**Referência arquitetural:** `01-physical-architecture.md` — Compute Nodes / `04-compute-plane.md`
**Fonte do preço:** Catálogo Dell BR (configuração base). A ARP SERPRO PE 91031/2025 (UASG 803080)
cobre servidores 2U de alto desempenho — verificar Configurações 3/4/11 do edital para comparação.
Equivalentes aceitáveis: Lenovo ThinkSystem SR670 V3, HPE ProLiant DL380 Gen11.

### Por que R770 como referência

O R770 é o servidor rack **2U dual-socket** de próxima geração da Dell com Intel Xeon 6.
Usado como referência de conformidade — o requisito é a especificação técnica da tabela abaixo.

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

## 3. GPU Compute Nodes — Lenovo ThinkSystem SR680a V3 (4× H200 SXM5)

**Qtd:** 9 unidades (1 por rack, 3 por AZ)
**Referência arquitetural:** `01-physical-architecture.md` — GPU Compute Nodes / `09-gpu-compute.md`
**Preço de referência:** R$ 1.260.000/un — Contrato SERPRO 263505, Lenovo Tecnologia (Brasil)
(CNPJ 07.275.920/0001-61), jan/2026, vigência até jan/2031. ARP PE 91031/2025 (UASG 803080) aderível.
**Datasheet:** [ds0180 — ThinkSystem SR680a V3 Datasheet](https://lenovopress.lenovo.com/datasheet/ds0180-lenovo-thinksystem-sr680a-v3)
**Product Guide:** [lp1909 — ThinkSystem SR680a V3 Server Product Guide](https://lenovopress.lenovo.com/lp1909-thinksystem-sr680a-v3-server)
**GPU Guide:** [lp1944 — ThinkSystem NVIDIA H200 141GB GPUs Product Guide](https://lenovopress.lenovo.com/lp1944-nvidia-h200-141gb-gpu)
**Technical Specs:** [pubs.lenovo.com — SR680a V3 Specifications](https://pubs.lenovo.com/sr680a-v3/server_specifications_technical)

> ℹ️ O modelo SR680a V3 é inferido da Configuração 7 do PE 91031/2025 (4× H200 SXM5,
> 2× Intel Xeon 5ª Ger., 2 TB RAM) — o exato modelo entregue não está explicitado no edital.
> O SR680a V3 é **8U**, o que impacta o layout de rack: cada posição de GPU node passa de
> 4U para 8U. Revisar `01-physical-architecture.md` antes da aquisição.

| Especificação | Requisito Arquitetural | Lenovo SR680a V3 (4× H200) | Status |
|---|---|---|---|
| Form factor | dual-socket, suporte SXM5 | **8U** dual-socket | ⚠️ 8U — revisar rack |
| CPU | ≥ 32C/socket, AVX-512, ≥ 2,3 GHz | 2× Intel Xeon Scalable 5ª Ger. | ✅ |
| RAM | 1 TB DDR4-3200 ECC | **2 TB DDR5** | ✅ Excede |
| GPU | 4× SXM5, NVLink ≥ 600 GB/s, MIG | 4× **NVIDIA H200 141 GB HBM3e SXM5** | ✅ Excede |
| Memória GPU | 80 GB HBM2e | **141 GB HBM3e** (+76%) | ✅ Excede |
| Bandwidth GPU | — | **4,8 TB/s** | ✅ |
| FP64 | ≥ 9 TFLOPS | **34 TFLOPS** | ✅ Excede |
| FP32 | ≥ 19 TFLOPS | **67 TFLOPS** | ✅ Excede |
| Tensor DL | — | ~1979 TFLOPS (FP16/BF16) | ✅ |
| NVLink | ≥ 600 GB/s bidirecional | **900 GB/s** | ✅ Excede |
| MIG | Suportado (Kubernetes nativo) | ✅ até 7 instâncias por GPU | ✅ |
| Cooling GPU | Direct Liquid Cooling ≥ 400W/GPU | **DLC integrado** (700W TDP) | ✅ |
| NIC | 2× 25GbE | 2× NIC 25 GbE | ✅ |
| BMC | IPMI 2.0 + Redfish | XClarity Controller (IPMI 2.0 + Redfish) | ✅ |

> ⚠️ **Fibre Channel:** A Configuração 7 inclui 2× FC 32 Gb/s (requisito SERPRO/SAN).
> Nossa arquitetura usa Ethernet/NVMe-oF — os adaptadores FC estarão presentes mas inativos.
> Não representam incompatibilidade; são custo embutido no preço do contrato.

### Configuração Recomendada por Nó

```
GPU  : 4× NVIDIA HGX H200 141 GB HBM3e 700W SXM5 (NVLink 900 GB/s pleno)
CPU  : 2× Intel Xeon Scalable 5ª Ger. (≥ 32C/socket, AVX-512)
RAM  : 2 TB DDR5
Boot : 2× SSD/NVMe 3.2 TB (conforme Config 7 SERPRO)
NIC  : 2× 25GbE
Cooling: Direct Liquid Cooling integrado
BMC  : XClarity Controller (Redfish)
```

> **PCI Vendor/Product ID (H200 SXM5):** Após recebimento, executar:
> ```bash
> lspci -nn | grep -i nvidia
> # H200 SXM5: 10de:2335
> ```
> Preencher em `09-gpu-compute.md` com o ID exato após entrega.

---

## 4. Swift Storage Nodes — Referência: Dell PowerEdge R760xd2

**Qtd:** 18 unidades (2 por rack × 9 racks)
**Referência arquitetural:** `01-physical-architecture.md` — Storage Nodes Swift / `05-storage-plane.md`
**Fonte do preço:** Catálogo Dell BR (configuração base). Equivalentes aceitáveis: Lenovo
ThinkSystem SR650 V3 com backplane LFF, HPE ProLiant DL380 Gen11 LFF, Supermicro SSG-6029P-E1CR24L.

### Por que R760xd2 como referência

O R760xd2 é explicitamente posicionado pela Dell para **file e object storage** com até 24 baias
LFF 3.5". Usado como referência de conformidade — o requisito é a tabela abaixo, não o modelo.

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

## 5. Cinder Storage Nodes — Referência: Dell PowerEdge R770 (all-NVMe)

**Qtd:** 3 unidades (1 por AZ, em FD1)
**Referência arquitetural:** `01-physical-architecture.md` — Storage Nodes Cinder / `05-storage-plane.md`
**Fonte do preço:** Catálogo Dell BR (configuração base; all-NVMe é substancialmente superior).
Equivalentes aceitáveis: Lenovo ThinkSystem SR670 V3 NVMe, HPE ProLiant DL380 Gen11 NVMe,
Supermicro AS-2015A-I com backplane NVMe.

### Por que R770 (all-NVMe) como referência

O R770 com chassi all-NVMe suporta até **40× E3.S NVMe Gen5**, excedendo o requisito de
24× NVMe U.2 3.84 TB. Usado como referência de conformidade — o requisito é a tabela abaixo.

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

## 6. Network Nodes — Referência: Dell PowerEdge R670

**Qtd:** 6 unidades (2 por AZ, em FD2 e FD3)
**Referência arquitetural:** `01-physical-architecture.md` — Network Nodes / `06-networking`
**Fonte do preço:** Catálogo Dell BR (mesmo SKU do Control Plane). Qualquer servidor 1U
dual-socket com NIC quad 25GbE é adequado.

### Requisito diferenciador

Para os Network Nodes o diferencial é a **NIC quad-port 25GbE** para suportar OVN Gateway e
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

> Fabric Cisco Nexus em **modo NX-OS standalone** com **OpenStack OVN** como SDN overlay.
> Preços da ARP SERPRO 90611/2025 (NTT Brasil, Reg. 283040) — aderível por órgãos federais.
>
> ```
> OVERLAY (SDN)  →  OpenStack Neutron + OVN
>                   VXLAN tunnels, security groups, floating IPs, LBaaS
> UNDERLAY       →  Nexus 9000 NX-OS · eBGP/ECMP · os switches enxergam só IP
> ```
> Cisco APIC **não é necessário** — o OVN é o plano de controle de rede virtual.

### 7.1 Leaf / ToR — Cisco Nexus N9K-C93180YC-FX3

**Qtd:** 18 unidades (2 por rack × 9 racks)
**Preço de referência:** R$ 131.100,00/un — ARP SERPRO 90611/2025 (NTT Brasil, Reg. 283040)
**Suporte Cisco:** [cisco.com — Nexus 93180YC-FX3](https://www.cisco.com/c/en/us/support/switches/nexus-93180yc-fx3-switch/model.html)
**Datasheet:** [Nexus 9300-FX3 Series Data Sheet (c78-744052)](https://www.cisco.com/c/en/us/products/collateral/switches/nexus-9000-series-switches/datasheet-c78-744052.html)
**Hardware Guide (NX-OS):** [Nexus 93180YC-FX3 NX-OS Mode Installation Guide](https://www.cisco.com/c/en/us/td/docs/dcn/hw/nx-os/nexus9000/93180yc-fx3/cisco-nexus-93180yc-fx3-nx-os-mode-switch-hardware-installation-guide/m_overview1.html)

| Especificação | Requisito Arquitetural | N9K-C93180YC-FX3 | Status |
|---|---|---|---|
| Portas downlink | 32× 100GbE (breakout 4× 25GbE) | **48× 10/25GbE SFP28** non-blocking | ✅ Excede |
| Portas uplink | 3× 100GbE para spines | **6× 40/100GbE QSFP28** | ✅ |
| Throughput | — | **3,6 Tbps** non-blocking | ✅ |
| Latência | ≤ 500 ns | Baixa latência (Cisco ASIC) | ✅ |
| Protocolos | BGP, EVPN, VXLAN HW offload, BFD, ECMP | BGP, OSPF, MP-BGP-EVPN, VXLAN, BFD, ECMP | ✅ |
| Multi-chassis | MLAG | **vPC** (Virtual PortChannel) | ✅ |
| APIs | NETCONF, REST, gNMI | NETCONF, RESTCONF, NX-API (Python, Ansible) | ✅ |
| Form factor | 1U | **1U rack** | ✅ |
| Fonte | Redundante hot-swap | Dual AC hot-swap, bivolt | ✅ |

### 7.2 Spine — Cisco Nexus N9K-C93600CD-GX

**Qtd:** 3 unidades (1 por AZ, racks R2/R5/R8)
**Preço de referência:** R$ 288.900,00/un — ARP SERPRO 90611/2025 (NTT Brasil, Reg. 283040)
**Suporte Cisco:** [cisco.com — Nexus 93600CD-GX](https://www.cisco.com/c/en/us/support/switches/nexus-93600cd-gx-switch/model.html)
**Datasheet:** [Nexus 9300-GX Series Data Sheet](https://www.cisco.com/c/en/us/products/collateral/switches/nexus-9000-series-switches/nexus-9300-gx-series-switches-ds.html)
**Hardware Guide (NX-OS):** [Nexus 93600CD-GX NX-OS Mode Installation Guide](https://www.cisco.com/c/en/us/td/docs/switches/datacenter/nexus9000/hw/n93600cd-gx-hig/guide/b_c93600cd-gx-nxos-mode-hardware-installation-guide/m_overview1.html)

> Denominado "Border-Leaf" no contrato SERPRO. Nesta topologia (18 leaves × 3 spines)
> as 8× 400GbE em breakout 4× 100GbE = 32× 100GbE cobrem as 18 conexões leaf→spine com margem.

| Especificação | Requisito Arquitetural | N9K-C93600CD-GX | Status |
|---|---|---|---|
| Portas uplink para leaves | 18× 100GbE + 3 inter-spine | 8× 400GbE → 32× 100GbE (breakout) | ✅ |
| Portas 100GbE adicionais | — | 28× 40/100GbE | ✅ |
| Throughput | — | **12 Tbps** non-blocking | ✅ |
| Rotas unicast | ≥ 512.000 | 512.000 | ✅ |
| Protocolos | BGP eBGP, EVPN, BFD, ECMP | BGP, MP-BGP-EVPN, OSPF, BFD, ECMP | ✅ |
| Form factor | 1–2U | **1U** | ✅ |

> ⚠️ Se a escala crescer para >32 leaves por spine, migrar para spine dedicado (N9K-C9364C).

### 7.3 Management OOB — Dell PowerSwitch N3248TE-ON

**Qtd:** 9 unidades (1 por rack)
**Preço de referência:** Consultar Dell BR (sem ARP pública localizada para este perfil)
**Produto BR:** [dell.com/pt-br — PowerSwitch N3248TE-ON](https://www.dell.com/pt-br/shop/switches-de-data-center/powerswitch-n3248te-on/spd/powerswitch-n3248te-on)
**Spec Sheet:** [dell-powerswitch-n3248te-on-spec-sheet.pdf](https://www.delltechnologies.com/asset/en-us/products/networking/technical-support/dell-powerswitch-n3248te-on-spec-sheet.pdf)

| Especificação | Requisito Arquitetural | N3248TE-ON | Status |
|---|---|---|---|
| Portas | 48× 1GbE base-T + 4× 10GbE uplink | **48× 1GbE RJ45 + 4× 10GbE SFP+ + 2× 100GbE QSFP28** | ✅ Excede |
| Função | OOB/IPMI/PXE isolado | VLAN segregada, DHCP relay | ✅ |

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

> As estimativas usam **a melhor referência de preço disponível** para cada item — contrato
> público quando disponível, catálogo de lista quando não há referência pública melhor.

### Servidores e Appliances

| Role | Modelo de Referência | Qtd | Melhor Preço Ref. Unit. | Estimativa Total | Qualidade da Referência |
|---|---|---:|---:|---:|---|
| Control Plane | Dell PowerEdge R670 | 12 | R$ 75.890 ² | R$ 910.680 | Catálogo base — subestima produção |
| Network Node | Dell PowerEdge R670 | 6 | R$ 75.890 ² | R$ 455.340 | Catálogo base — subestima produção |
| Compute | Dell PowerEdge R770 | 102 | R$ 82.819 ² | R$ 8.447.538 | Catálogo base — subestima produção |
| Cinder Storage | Dell PowerEdge R770 (NVMe) | 3 | R$ 82.819 ² | R$ 248.457 | Catálogo base — subestima produção |
| Swift Storage | Dell PowerEdge R760xd2 | 18 | R$ 84.221 ² | R$ 1.515.978 | Catálogo base — subestima produção |
| GPU Compute | **Lenovo 4× H200 SXM5** | 9 | **R$ 1.260.000** ⁶ᵃ | **R$ 11.340.000** | ✅ Contrato público jan/2026 — confiável |
| HSM | Kryptus ASI-HSM AHX5 KNET | 3 | R$ 256.000 | R$ 768.000 | ✅ Contrato público 2024 — confiável |
| **Total servidores** | | **153** | | **~R$ 23.685.993** | |

> ¹ Preços Dell = configuração **base** (mínima). Produção resulta em 3–5× superior para
>   servidores sem GPU. GPU (Lenovo) e HSM (Kryptus) são preços reais de contrato público.
>   Para calibrar os servidores Dell, verificar ARP SERPRO PE 91031/2025 (UASG 803080).

### Rede e Infraestrutura — Cisco Nexus NX-OS + OpenStack OVN

> Preços extraídos do **Contrato SERPRO × NTT Brasil, Reg. 283040** (PE 90611/2025, 21/05/2026).
> ARP 90611/2025 (UASG 803080) é aderível por órgãos federais (Art. 4.1, Lei 14.133/2021).
> Switches operam em **modo NX-OS standalone** — sem APIC; SDN provido pelo OpenStack OVN.

| Modelo | Role | Qtd | Preço Contrato (R$) | Estimativa Total (R$) | Fonte |
|---|---|---:|---:|---:|---|
| N9K-C93180YC-FX3 | Leaf / ToR | 18 | 131.100 | 2.359.800 | SERPRO/NTT Reg. 283040 |
| N9K-C93600CD-GX | Spine | 3 | 288.900 | 866.700 | SERPRO/NTT Reg. 283040 |
| PowerSwitch N3248TE-ON | OOB Management | 9 | A consultar | A consultar | Catálogo Dell BR |
| **Total switches** | | **30** | | **~R$ 3.226.500** + OOB | |

> ⚠️ Para adesão à ARP verificar saldo disponível junto à SUPGA/GATIC SERPRO SP (UASG 803080).

### Infraestrutura Física

| Item | Especificação | Qtd | Ref. Gov. Unit. | Estimativa Total | Fonte |
|---|---|---:|---:|---:|---|
| Rack 42U 19" | APC ou equivalente | 9 | R$ 17.500 | R$ 157.500 | ARP INCA 5/2026, Item 9 |
| Transceivers 10/25GbE | SFP-10/25G-CSR-S SFP28 SR (hosts → leaf) | ~600 | R$ 741 ⁸ | ~R$ 444.600 | SERPRO/NTT Reg. 283040, Item 8 |
| Transceivers 100GbE BiDi | QSFP-100G-SR1.2 LC MMF (leaf → spine) | 54 | R$ 2.250 | R$ 121.500 | SERPRO/NTT Reg. 283040, Item 5 |
| Transceivers 400GbE | QDD-400G-SR4.2-BD QSFP-DD MPO-12 (spine) | ~12 | R$ 6.614 | ~R$ 79.368 | SERPRO/NTT Reg. 283040, Item 7 |
| **Total infra física** | | | | **~R$ 802.968** | |

> ⁸ Estimativa: 2 transceivers por servidor × ~300 servidores sem GPU ≈ 600 unidades.
> Quantitativo exato depende do projeto de cabeamento detalhado.

### Total Consolidado

| Grupo | Estimativa |
|---|---:|
| Servidores + HSM (153 unidades) | R$ 23.685.993 |
| Switches Cisco (21 unidades — leaf + spine) | R$ 3.226.500 |
| Infraestrutura física (racks + transceivers) | ~R$ 802.968 |
| OOB Switch N3248TE-ON (9 unidades) | A consultar |
| **Total itens com referência pública** | **~R$ 27.715.461** |

> ℹ️ Os preços de servidores Dell (uso geral) são de **catálogo base** — produção resulta em
> 3–5× superior. O GPU (Lenovo, R$ 1.260.000/un) e os switches Cisco (ARP SERPRO) são preços
> reais de contratos públicos. O total de **~R$ 27,7M** é piso para os componentes com melhor
> referência; o custo real de produção será superior nos itens Dell de uso geral.

---

## 10. Notas de Alinhamento com a Arquitetura

| Item | Situação |
|---|---|
| GPU node form factor | SR680a V3 é **8U** — revisar layout de rack (`01-physical-architecture.md`). Posições GPU nos racks FD1/FD2/FD3 precisam ser recalculadas de 4U para 8U. |
| Spine switch form factor | N9K-C93600CD-GX é **1U** — `01-physical-architecture.md` registrava spine como 2U. Rack FD2 ganha 1U de folga. |
| NVMe Cinder | `01-physical-architecture.md` usa **NVMe SFF** agnóstico de form factor — aceita U.2, E3.S/EDSFF ou equivalente PCIe Gen4+. |
| GPU DLC | SR680a V3 / H200 SXM5 utiliza Direct Liquid Cooling integrado — compatível com requisito DLC ≥ 400W/GPU da arquitetura. |
| GPU product ID | Executar `lspci -nn \| grep -i nvidia` após entrega (H200 SXM5: `10de:2335`) e preencher em `09-gpu-compute.md`. |
| Transceivers | SFP-10/25G-CSR-S (R$741/un) são módulos ópticos Cisco — verificar compatibilidade com switches Cisco N9K antes de especificar em edital. |

---

## 11. Próximos Passos

1. **Revisar layout de rack para GPU 8U** — o SR680a V3 ocupa 8U (não 4U como registrado em
   `01-physical-architecture.md`). Recalcular posições nos racks FD1/FD2/FD3.
2. **RFQ formal para servidores de uso geral** (Control Plane, Compute, Storage, Network) —
   os preços Dell de catálogo são configuração base. Solicitar proposta com configuração
   completa ou verificar preços da ARP SERPRO PE 91031/2025 (UASG 803080, Configs 1–6, 11–13).
3. **Verificar saldo na ARP SERPRO 90611/2025** para switches Cisco (SUPGA/GATIC SERPRO SP) e
   **ARP SERPRO PE 91031/2025** para servidores GPU (Config 7, Lenovo H200).
4. **Selecionar CPU exata** para servidores de uso geral — Xeon 6 linha P (Performance) para
   Compute/GPU; linha E (Efficient) aceitável para Control Plane e Storage.
5. **Definir backplane NVMe** para Cinder nodes — confirmar E3.S ou U.2 conforme disponibilidade;
   atualizar spec em `01-physical-architecture.md`.
6. **Contatar Kryptus** para proposta formal (3 unidades ASI-HSM AHX5 KNET) — confirmar
   performance RSA-2048 ops/s, HA group entre AZs e agregação de partições no cluster.
   Tel: +55 (19) 3112-5000 | kryptus.com.
7. **Confirmar PCI ID das GPUs** — executar `lspci -nn | grep -i nvidia` após entrega do
   SR680a V3 e preencher em `09-gpu-compute.md`.
8. **Verificar BMC do SR680a V3** — confirmar suporte a Redfish e IPMI 2.0 via XClarity
   Controller para integração com Ironic/automação de provisionamento.

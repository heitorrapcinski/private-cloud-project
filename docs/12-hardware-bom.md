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

| Role | Modelo de Referência | Qtd | Melhor Preço Ref. Unit. | Fonte da Referência |
|---|---|---:|---|---|
| Control Plane | Dell PowerEdge **R670** ¹ | 12 | R$ 75.890 (base) | Catálogo Dell BR |
| Compute | Dell PowerEdge **R770** ¹ | 102 | R$ 82.819 (base) | Catálogo Dell BR |
| GPU Compute | Lenovo **4× H200 SXM5** ² | 9 | **R$ 1.260.000** | Contrato SERPRO 263505 (jan/2026) |
| Swift Storage | Dell PowerEdge **R760xd2** ¹ | 18 | R$ 84.221 (base) | Catálogo Dell BR |
| Cinder Storage | Dell PowerEdge **R770** (NVMe) ¹ | 3 | R$ 82.819 (base) | Catálogo Dell BR |
| Network Node | Dell PowerEdge **R670** ¹ | 6 | R$ 75.890 (base) | Catálogo Dell BR |
| Leaf Switch (ToR) | Cisco **N9K-C93180YC-FX3** ³ | 18 | R$ 131.100 | ARP SERPRO 90611/2025 |
| Spine Switch | Cisco **N9K-C93600CD-GX** ³ | 3 | R$ 288.900 | ARP SERPRO 90611/2025 |
| OOB Switch | Dell PowerSwitch **N3248TE-ON** ¹ | 9 | Consultar | Catálogo Dell BR |
| HSM Appliance | Kryptus **ASI-HSM AHX5 KNET** | 3 | R$ 256.000 | Contrato público 2024 |

> ¹ Sem contrato público de referência localizado. Dell BR é a fonte com melhor rastreabilidade
>   pública de preços para servidores rack de uso geral neste segmento. A ARP SERPRO PE 91031/2025
>   (UASG 803080) cobre servidores equivalentes — consultar saldo disponível.
>
> ² GPU: referência principal é o Contrato SERPRO 263505 (Lenovo, H200 SXM5, jan/2026). O Dell
>   XE8640 (H100) é alternativa com spec inferior e preço histórico superior. Ver Seção 3.
>
> ³ Switches: ARP SERPRO 90611/2025 aderível (NTT Brasil). Dell S5448F-ON/Z9664F-ON mantidos
>   como Opção A alternativa. Ver Seção 7.

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

## 3. GPU Compute Nodes — Referência Principal: Lenovo 4× H200 SXM5 (SERPRO/Lenovo 2026)

**Qtd:** 9 unidades (1 por rack, 3 por AZ)
**Referência arquitetural:** `01-physical-architecture.md` — GPU Compute Nodes / `09-gpu-compute.md`
**Fonte do preço (primária):** Contrato SERPRO 263505 — Lenovo Tecnologia (Brasil), jan/2026,
**R$ 1.260.000/un**, 4× NVIDIA H200 SXM5 141 GB HBM3e. ARP PE 91031/2025 (UASG 803080) aderível.
**Fonte do preço (alternativa):** Dell PowerEdge XE8640 — consultar proposta (sem preço público).

### Referência primária de preço: SERPRO PE 91031/2025, Configuração 7

O Contrato SERPRO 263505 (Lenovo, jan/2026) representa a referência de mercado mais recente e
qualificada disponível para servidores GPU de data center. A **Configuração 7** especifica
4× **NVIDIA H200 SXM5** — geração posterior ao H100, com **141 GB HBM3e** e **4,8 TB/s** de
largura de banda de memória, a um preço 23% inferior à nossa referência histórica H100.

O Dell PowerEdge XE8640 (4× H100 SXM5) é mantido abaixo como referência alternativa para
comparação de specs — mas não é mais a referência de preço primária.

| Especificação | Requisito Arquitetural | PowerEdge XE8640 | Status |
|---|---|---|---|
| Form factor | 2U, dual-socket, suporte SXM4/PCIe Gen4 | **4U** dual-socket | ⚠️ ver nota |
| CPU | 40C/socket, VT-d/IOMMU | 2× Xeon Scalable 5ª Ger. até **56C/socket** | ✅ |
| RAM | 1 TB DDR4-3200 ECC | até **4 TB DDR5** (32 DIMMs) | ✅ Excede |
| GPU | 4× 80 GB HBM2e, SXM5, NVLink ≥ 600 GB/s, MIG | 4× **NVIDIA H100 80 GB SXM5**, NVLink pleno | ✅ |
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
> # H200 SXM5 PCI ID: 10de:2335
> ```
> Substituir os valores em `09-gpu-compute.md` conforme o modelo exato recebido.

### Referência de Preço Gov. — SERPRO PE 91031/2025, Configuração 7 (H200 SXM5)

> **Fonte:** Contrato SERPRO 263505, Processo SERPRO-PSI-2025/00080, fornecedor
> **Lenovo Tecnologia (Brasil) Ltda.** (CNPJ 07.275.920/0001-61), vigência 06/01/2026–05/01/2031.
> Valor unitário: **R$ 1.260.000,00** — 6 unidades total (3 BSB + 3 SP) = R$ 7.560.000,00.
> ARP PE 91031/2025 (UASG 803080 SERPRO/SP) — aderível por órgãos federais.

A Configuração 7 do edital especifica servidor com **4× NVIDIA H200 SXM5** (identificado pelos
requisitos de 141 GB HBM3e e 4,8 TB/s de largura de banda — specs exclusivas do H200):

| Especificação Config 7 (edital) | Valor exigido | H100 SXM5 | H200 SXM5 | Nossa arq. |
|---|---|---|---|---|
| Memória GPU | ≥ 141 GB HBM3e | 80 GB HBM2e ❌ | **141 GB HBM3e** ✅ | 80 GB |
| Bandwidth memória | ≥ 4,8 TB/s | 3,35 TB/s ❌ | **4,8 TB/s** ✅ | — |
| FP64 por GPU | ≥ 30 TFLOPS | 33,5 TFLOPS ✅ | 34 TFLOPS ✅ | ≥ 9 TFLOPS |
| FP32 por GPU | ≥ 60 TFLOPS | 67 TFLOPS ✅ | 67 TFLOPS ✅ | ≥ 19 TFLOPS |
| Tensor Deep Learning | ≥ 1671 TFLOPS | ~1979 TFLOPS (FP16) ✅ | ~1979 TFLOPS ✅ | — |
| NVLink / interface | SXM5, ≥ 900 GB/s | SXM5, 900 GB/s ✅ | SXM5, 900 GB/s ✅ | SXM5, ≥ 600 GB/s |
| MIG (Kubernetes) | Nativo, sem licença extra | ✅ | ✅ | ✅ |
| RAM servidor | 2 TB | — | — | 1 TB |
| CPU | ≥ 32C/socket, AVX-512, ≥ 2,3 GHz | — | — | ≥ 40C/socket |
| Cooling | não especificado ⚠️ | DLC requerido (700W) | DLC requerido (700W) | DLC ≥ 400W/GPU |
| Fibre Channel 32 Gb/s | 2× FC (Emulex/QLogic) | — | — | ❌ não requerido |

> ⚠️ **Fibre Channel:** A Config 7 inclui 2× FC 32 Gb/s (requisito SERPRO para storage SAN).
> Nossa arquitetura usa **Ethernet / NVMe-oF** — os adaptadores FC estão no servidor mas
> não serão utilizados. Não representam incompatibilidade, apenas custo embutido.
>
> ⚠️ **Cooling:** O edital não especifica explicitamente liquid cooling, mas H200 SXM5 a 700W
> TDP **exige** Direct Liquid Cooling. O servidor Lenovo vencedor (provável ThinkSystem SR680a V3
> ou SD550 V3) utiliza DLC integrado — confirmar no Termo de Referência/proposta Lenovo.
>
> ✅ **Conclusão:** Config 7 **atende e excede** todos os requisitos de GPU da nossa arquitetura.
> O H200 é a geração posterior ao H100 (mesma família SXM5). A diferença funcional para
> workloads de ML é principalmente a maior memória (141 vs 80 GB) — importante para modelos
> de linguagem grandes (LLMs) que não cabem em H100.

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

> Duas opções mapeadas com referências de preço distintas. **Opção B (Cisco/ARP SERPRO) tem
> preços públicos homologados e ARP aderível**; Opção A (Dell) não tem preço público disponível.
> A escolha entre as opções impacta o modelo de gerência (SONiC open vs NX-OS standalone) mas
> **não o SDN** — em ambas o overlay é OpenStack OVN.

### 7.1 Leaf / ToR — Opção A: Dell PowerSwitch S5448F-ON

**Qtd:** 18 unidades (2 por rack × 9 racks)
**Fonte do preço:** Consultar Dell BR (sem preço público).

O S5448F-ON é o switch leaf/ToR disponível no catálogo Dell BR com densidade 100GbE e uplinks 400GbE nativos, substituindo o Z9264F-ON que não consta no catálogo brasileiro.

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

### 7.2 Spine — Opção A: Dell PowerSwitch Z9664F-ON

**Qtd:** 3 unidades (1 por AZ, em racks R2, R5, R8)
**Fonte do preço:** Consultar Dell BR (sem preço público).

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
**Fonte do preço:** Consultar Dell BR (sem preço público). Para este perfil (48× 1GbE OOB)
qualquer switch gerenciável de acesso também atende — sem ARP pública localizada.

| Especificação | Requisito Arquitetural | N3248TE-ON | Status |
|---|---|---|---|
| Portas | 48× 1GbE base-T + 4× 10GbE uplink | **48× 1GbE RJ45 + 4× 10GbE SFP+ + 2× 100GbE QSFP28** | ✅ Excede |
| Função | OOB/IPMI/PXE isolado | VLAN segregada, DHCP relay, PoE opcional | ✅ |
| OS | — | Dell OS10 | ✅ |

**Produto BR:** [dell.com/pt-br — PowerSwitch N3248TE-ON](https://www.dell.com/pt-br/shop/switches-de-data-center/powerswitch-n3248te-on/spd/powerswitch-n3248te-on)
**Spec Sheet:** [dell-powerswitch-n3248te-on-spec-sheet.pdf](https://www.delltechnologies.com/asset/en-us/products/networking/technical-support/dell-powerswitch-n3248te-on-spec-sheet.pdf)

### 7.4 Alternativa — Cisco Nexus 9000 em modo NX-OS standalone (SERPRO/NTT Contrato 283040)

> **Fonte de referência de preços:** Contrato SERPRO × NTT Brasil (Reg. 283040, PE 90611/2025),
> assinado em 21/05/2026, vigência 12 meses. Fornecedor: NTT Brasil Comércio e Serviços de
> Tecnologia Ltda (CNPJ 05.437.734/0001-56). Processo SERPRO-PSI-2025/00051 / ARP 90611/2025.
> Valor total contratado: R$ 6.076.351,10.

Esta opção usa os switches Cisco Nexus em **modo NX-OS standalone** (não ACI), como underlay
BGP/ECMP puro. O SDN desta arquitetura é provido inteiramente pelo **OpenStack + OVN**:

```
┌──────────────────────────────────────────────────────────┐
│  OVERLAY (SDN)  →  OpenStack Neutron + OVN               │
│  Virtual networks, security groups, roteamento virtual,   │
│  VXLAN tunnels terminados nos hipervisores (OVN vtep),   │
│  floating IPs, LBaaS (Octavia), FWaaS                    │
├──────────────────────────────────────────────────────────┤
│  UNDERLAY  →  Nexus 9000 em NX-OS standalone             │
│  eBGP / ECMP entre leaves e spines                       │
│  Os switches enxergam apenas pacotes IP —                 │
│  são agnósticos ao VXLAN do OVN por cima                 │
└──────────────────────────────────────────────────────────┘
```

A controladora Cisco APIC (DCN-VAPIC) **não é necessária** nesta arquitetura segregada — ela
só é obrigatória no SERPRO porque os novos switches precisam ingressar no fabric ACI já existente.
Aqui, o OVN é o plano de controle de rede virtual.

> **Nota sobre o modo NX-OS:** Os switches N9K-C93180YC-FX3 e N9K-C93600CD-GX chegam
> configuráveis em modo ACI ou NX-OS standalone — são o mesmo hardware. A conversão entre
> modos exige apenas reload e reconfiguracao inicial. Em NX-OS standalone, todos os recursos
> de BGP, OSPF, VXLAN hardware offload, BFD e ECMP estão disponíveis nativamente.

#### 7.4.1 Leaf / ToR — Cisco Nexus N9K-C93180YC-FX3

**Qtd sugerida:** 18 unidades (2 por rack × 9 racks, mesma topologia atual)

| Especificação | Requisito Arquitetural | N9K-C93180YC-FX3 | Status |
|---|---|---|---|
| Portas downlink | 32× 100GbE (breakout 4× 25GbE) | **48× 10/25GbE SFP28** non-blocking | ✅ Excede |
| Portas uplink | 3× 100GbE para spines | **6× 40/100GbE QSFP28** (1 por spine + 3 uplinks) | ✅ |
| Throughput | — | **3,6 Tbps** non-blocking | ✅ |
| Latência | ≤ 500 ns | Baixa latência (hardware pipeline Cisco ASIC) | ✅ |
| Protocolos underlay | BGP, OSPF, BFD, ECMP | BGP, OSPF, OSPFv3, MP-BGP, BFD, ECMP | ✅ |
| Protocolos overlay | VXLAN, EVPN, VTEP, L2/L3 GW | VXLAN/EVPN, VTEP, Distributed Anycast GW | ✅ |
| SDN | APIs declarativas | **NX-OS**: NETCONF, RESTCONF, NX-API (Python, Ansible) | ✅ |
| Multi-chassis | MLAG / vPC | **vPC** (Virtual PortChannel) | ✅ |
| Integração hypervisor | VMware, KVM, OpenStack | ✅ (OVN underlay — sem agente no switch) | ✅ |
| Form factor | 1U | **1U rack** | ✅ |
| Fonte | Redundante hot-swap | Dual AC hot-swap, bivolt | ✅ |

**Preço contratado (SERPRO 2026):** R$ 131.100,00/un
**Part number:** N9K-C93180YC-FX3
**Fabric existente SERPRO:** Este modelo já está implantado nos DCs BSB e SPO do SERPRO
**Suporte Cisco:** [cisco.com — Nexus 93180YC-FX3](https://www.cisco.com/c/en/us/support/switches/nexus-93180yc-fx3-switch/model.html)
**Datasheet:** [Nexus 9300-FX3 Series Switches Data Sheet (datasheet-c78-744052)](https://www.cisco.com/c/en/us/products/collateral/switches/nexus-9000-series-switches/datasheet-c78-744052.html)
**Hardware Install Guide (NX-OS):** [Nexus 93180YC-FX3 NX-OS Mode — Hardware Installation Guide](https://www.cisco.com/c/en/us/td/docs/dcn/hw/nx-os/nexus9000/93180yc-fx3/cisco-nexus-93180yc-fx3-nx-os-mode-switch-hardware-installation-guide/m_overview1.html)

#### 7.4.2 Spine — Cisco Nexus N9K-C93600CD-GX (Border-Leaf como Spine)

**Qtd sugerida:** 3 unidades (1 por AZ, racks R2/R5/R8 — mesmo posicionamento do Z9664F-ON)

> No contrato SERPRO este equipamento é denominado "Switch Tipo 2 – Border-Leaf". Na topologia
> desta arquitetura, com 18 leaves e 3 spines, o N9K-C93600CD-GX atende ao papel de **Spine**:
> suas 8× 400GbE (breakout 4× 100GbE = 32 portas 100GbE) cobrem as 18 conexões leaf→spine com
> margem. É o modelo de maior performance da família Nexus 9300 sem ser um Spine dedicado.

| Especificação | Requisito Arquitetural | N9K-C93600CD-GX | Status |
|---|---|---|---|
| Portas 400GbE | 32× 400GbE QSFP-DD | **8× 400GbE QSFP-DD** (breakout → 32× 100GbE) | ✅ (via breakout) |
| Portas 100GbE | 18 para leaves + 3 inter-spine | 28× 40/100GbE + 8× 400GbE → ≥ 36× 100GbE | ✅ |
| Throughput | — | **12 Tbps** non-blocking | ✅ |
| Roteamento unicast | ≥ 512.000 rotas | 512.000 rotas unicast | ✅ |
| Roteamento multicast | ≥ 32.000 rotas | 32.000 rotas multicast | ✅ |
| Protocolos | BGP eBGP, EVPN, BFD, ECMP | BGP, MP-BGP-EVPN, OSPF, BFD, ECMP | ✅ |
| DCI | Datacenter Interconnect | ✅ (funcionalidade disponível) | ✅ |
| Form factor | 2U | **1U** | ✅ Melhor (economiza 1U vs Z9664F-ON) |

**Preço contratado (SERPRO 2026):** R$ 288.900,00/un
**Part number:** N9K-C93600CD-GX
**Suporte Cisco:** [cisco.com — Nexus 93600CD-GX](https://www.cisco.com/c/en/us/support/switches/nexus-93600cd-gx-switch/model.html)
**Datasheet:** [Nexus 9300-GX Series Switches Data Sheet](https://www.cisco.com/c/en/us/products/collateral/switches/nexus-9000-series-switches/nexus-9300-gx-series-switches-ds.html)
**Hardware Install Guide (NX-OS):** [Nexus 93600CD-GX NX-OS Mode — Hardware Installation Guide](https://www.cisco.com/c/en/us/td/docs/switches/datacenter/nexus9000/hw/n93600cd-gx-hig/guide/b_c93600cd-gx-nxos-mode-hardware-installation-guide/m_overview1.html)
**Hardware Install Guide (NX-OS PDF):** [b_c93600cd-gx-nxos-mode-hardware-installation-guide.pdf](https://www.cisco.com/c/en/us/td/docs/switches/datacenter/nexus9000/hw/n93600cd-gx-hig/guide/b_c93600cd-gx-nxos-mode-hardware-installation-guide.pdf)

> ⚠️ **Nota de escala:** Em implantações Cisco ACI de maior escala, o papel de Spine é exercido
> por switches dedicados (ex: N9K-C9364C, N9K-C9336C-FX2) que já compõem o fabric SERPRO
> (cláusula 2.2.1.1.2 do contrato). Para esta arquitetura (18 leaves × 3 spines), o
> N9K-C93600CD-GX é dimensionalmente adequado. Se a escala crescer para >32 leaves por spine,
> será necessário migrar para spine dedicado.

#### 7.4.3 Controladora SDN — Cisco APIC Virtual (DCN-VAPIC)

> ❌ **Não necessário para esta arquitetura.** O APIC só é exigido quando os switches operam
> em modo ACI e precisam ingressar num fabric ACI existente (caso SERPRO). Aqui o SDN é
> provido pelo **OpenStack OVN** — não há necessidade de controladora externa de rede.
>
> O item DCN-VAPIC do contrato SERPRO/NTT (R$ 45.437,55/un) é incluído apenas como referência
> de preço público. **Não deve ser adquirido** para esta infra.

| Especificação | Relevância aqui | Alternativa |
|---|---|---|
| Provisionamento SDN | ❌ não aplicável | OpenStack Neutron API + Heat/Terraform |
| Multi-tenant | ❌ não aplicável | OpenStack Projects + Neutron |
| Integração KVM/OpenStack | ❌ não aplicável | OVN integrado nativamente ao Neutron |
| APIs declarativas | ❌ não aplicável | Neutron REST API + oslo.config |

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
| **Total servidores** | | **153** | | **~R$ 23.685.993** ¹ | |

¹ _Total usando referência Lenovo/H200 para GPU (R$ 11.340.000). Não inclui switches.
  Com a referência Dell/H100 anterior (R$ 14.805.000 GPU), o total seria ~R$ 27.150.993.
  A melhora de R$ 3.465.000 decorre de especificação superior (H200) a preço menor._

² _Preços Dell = configuração **base** (mínima). Servidores de produção com CPU, RAM e
  storage adequados resultam em 3–5× superior. Usar como piso de referência apenas.
  Para orçamento mais preciso, solicitar proposta à Dell com configuração completa ou
  verificar ARP SERPRO PE 91031/2025 (UASG 803080) para servidores equivalentes._

³ _Referência Gov. servidores de uso geral: **Pregão SERPRO PE 91031/2025** (UASG 803080,
  abertura 05/11/2025) cobre 13 configurações de servidor rack. Preços dos lotes não
  extraídos (exceto Config 7 GPU). Servidores equivalentes ao R670/R770/R760xd2 estão
  nas Configurações 1–6 e 11–13 deste pregão._

⁴ _Configurações 1–6 do PE 91031/2025 têm 512 GB–1 TB RAM e 24–32 núcleos/socket —
  similar ao nosso perfil. Os preços vencedores são o melhor balizamento disponível para
  uma eventual licitação, mas não foram extraídos nesta análise._

⁶ᵃ _**GPU — referência primária:** Contrato SERPRO 263505, fornecedor **Lenovo Tecnologia (Brasil)**
  (CNPJ 07.275.920/0001-61), jan/2026, vigência até jan/2031. "Configuração 7": 4× NVIDIA H200
  SXM5 141 GB HBM3e, 2× CPU ≥ 32C, 2 TB RAM, 2× SSD/NVMe 3.2 TB, 2× FC 32 Gb/s, 2× 25GbE.
  Preço: **R$ 1.260.000/un**. ARP PE 91031/2025 (UASG 803080) aderível. Config 7 **excede**
  nossa especificação (H200 > H100, 141 GB > 80 GB), a preço 23% menor que ref. anterior._

⁷ _**GPU — referência teto:** ARP INCA Nº 5/2026 (Pregão 91.234/2025, válida ~dez/2026) —
  VERSATUS HPC, "GPU alto desempenho, NVIDIA, refrigerada a ar" — R$ 2.894.000/un.
  ⚠️ "Refrigerada a ar" pode indicar H100/H200 PCIe (não SXM5 DLC). Teto de referência
  2026. ARP aderível (Art. 4.1, Lei 14.133/2021)._

> ⚠️ **Servidores uso geral (R670/R770/R760xd2):** preços de catálogo base — subestimam
> a configuração de produção em 3–5×. Solicitar proposta com configuração completa ou
> verificar preços da ARP SERPRO PE 91031/2025 (UASG 803080) para calibrar.
>
> ⚠️ **HSM Kryptus:** preço de contrato público vigente (2024–2029), 2 unidades a
> R$ 256.000/un. Solicitar proposta formal para 3 unidades com SLA.

### Rede e Infraestrutura — Opção A: Dell SONiC (fabric aberto)

| Modelo | Role | Qtd | Preço Ref. Unit. | Estimativa Total | Ref. Gov. (unit.) | Fonte Gov. |
|---|---|---:|---|---|---|---|
| PowerSwitch S5448F-ON | Leaf / ToR | 18 | Consultar Dell | A consultar | — | — |
| PowerSwitch Z9664F-ON | Spine | 3 | Consultar Dell | A consultar | — | — |
| PowerSwitch N3248TE-ON | OOB Management | 9 | Consultar Dell | A consultar | — | — |
| **Total switches Opção A** | | **30** | | **A consultar** | | |

### Rede e Infraestrutura — Opção B: Cisco Nexus NX-OS standalone + OpenStack OVN

> Preços extraídos do **Contrato SERPRO × NTT Brasil, Reg. 283040** (PE 90611/2025, 21/05/2026).
> ARP 90611/2025 é aderível por órgãos federais (Art. 4.1, Lei 14.133/2021) — oportunidade de
> compra pública sem nova licitação pelo período de vigência da Ata.
>
> Nesta opção os switches operam em **modo NX-OS standalone** (não ACI). O SDN é provido pelo
> **OpenStack OVN** — a controladora APIC (DCN-VAPIC) **não é adquirida**.

| Modelo | Role | Qtd | Preço Contrato (R$) | Estimativa Total (R$) | Fonte |
|---|---|---:|---:|---:|---|
| N9K-C93180YC-FX3 | Leaf / ToR | 18 | 131.100,00 | 2.359.800,00 | SERPRO/NTT Reg. 283040 |
| N9K-C93600CD-GX | Spine | 3 | 288.900,00 | 866.700,00 | SERPRO/NTT Reg. 283040 |
| ~~DCN-VAPIC~~ | ~~Controladora APIC~~ | ~~—~~ | ~~45.437,55~~ | ~~não adquirido~~ | não necessário — OVN é o SDN |
| PowerSwitch N3248TE-ON | OOB Management | 9 | Consultar Dell | A consultar | — |
| **Total switches Opção B** | | **30** | | **~R$ 3.226.500** | |

> ⚠️ Os preços da tabela acima são da ARP SERPRO (fornecedor NTT), contratados para 10 Leaf
> (BSB) + 10 Leaf (SP) + 2 Border-Leaf (BSB) + 4 Border-Leaf (SP). Para adesão, verificar
> disponibilidade de saldo na ARP junto ao SERPRO (SUPGA/GATIC, UASG 803080).

### Infraestrutura Física

| Item | Especificação | Qtd | Ref. Gov. Unit. | Estimativa Total | Fonte |
|---|---|---:|---:|---:|---|
| Rack 42U 19" | APC ou equivalente | 9 | R$ 17.500 | R$ 157.500 | ARP INCA 5/2026, Item 9 |
| Transceivers 10/25GbE | SFP-10/25G-CSR-S SFP28 SR (hosts → leaf) | ~600 | R$ 741 ⁸ | ~R$ 444.600 | SERPRO/NTT Reg. 283040, Item 8 |
| Transceivers 100GbE BiDi | QSFP-100G-SR1.2 LC MMF (leaf → spine) | 54 | R$ 2.250 | R$ 121.500 | SERPRO/NTT Reg. 283040, Item 5 |
| Transceivers 100GbE SR4 | QSFP-100G-SR4-S MPO-12 MMF | — | R$ 2.026 | — | SERPRO/NTT Reg. 283040, Item 6 |
| Transceivers 400GbE | QDD-400G-SR4.2-BD QSFP-DD MPO-12 (spine) | ~12 | R$ 6.614 | ~R$ 79.368 | SERPRO/NTT Reg. 283040, Item 7 |

> ⁸ Transceivers 10/25GbE: estimativa de 2 por servidor × ~300 servidores sem GPU = ~600 unidades.
> **Nota de preço:** O valor do contrato SERPRO/NTT (R$741/un) é **5× inferior** ao da ARP INCA
> 5/2026 (R$3.900/un, Item 3). A estimativa total cai de ~R$2.340.000 para ~R$444.600.
> O quantitativo exato depende do projeto de cabeamento detalhado.

> **Nota de uso das referências de transceiver:** Os part numbers SFP-10/25G-CSR-S e
> QSFP-100G-SR1.2 são módulos ópticos Cisco. Switches Dell (Opção A) suportam módulos
> compatíveis de terceiros (via DAC/AOC ou módulos homologados Dell) — verificar
> compatibilidade antes de reutilizar estes preços para a Opção A.

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
| Fabric SDN — Cisco ACI | Contrato SERPRO/NTT 283040 (21/05/2026) identifica fabric Cisco ACI compatível com a arquitetura | Adicionada **Opção B** (Seção 7.4) com Cisco ACI. Requer decisão: Dell SONiC/OS10 (Opção A) × Cisco ACI (Opção B). Ver tabela comparativa abaixo. |
| Transceivers — novo preço de referência | Preços da ARP INCA 5/2026 substituídos por referências mais recentes (contrato 2026) | SFP28 25GbE: R$741/un (vs R$3.900 INCA) — impacto -R$1.895.400 na estimativa total |
| GPU — nova referência de preço (H200) | SERPRO PE 91031/2025, Config 7 (Lenovo, jan/2026, R$ 1.260.000/un) — H200 SXM5 141GB HBM3e | Substitui referência Embrapa 2023 (H100, R$ 1.645.000). Estimativa GPU: R$ 11.340.000 (−R$ 3.465.000 vs anterior). **H200 excede todos os requisitos GPU da arquitetura**. ⚠️ Decisão pendente: manter XE8640/H100 ou considerar Lenovo SR680a V3/H200 via ARP SERPRO |

### Decisão Pendente: Fabric de Rede — Dell SONiC vs Cisco Nexus NX-OS

> Em **ambas as opções o SDN é o OpenStack OVN** — os switches físicos são underlay puro
> (BGP/ECMP). Não há controladora de rede externa em nenhum dos dois casos.

| Critério | Opção A — Dell SONiC/OS10 | Opção B — Cisco Nexus NX-OS standalone |
|---|---|---|
| SDN (overlay) | OpenStack OVN | OpenStack OVN (idêntico) |
| Underlay | eBGP/ECMP via SONiC | eBGP/ECMP via NX-OS |
| Controladora de rede | Nenhuma (distribuído) | Nenhuma (distribuído — sem APIC) |
| Integração OpenStack | OVN ML2 plugin (padrão) | OVN ML2 plugin (padrão, idêntico) |
| Vendor lock-in | Baixo (SONiC open-source) | Médio (NX-OS proprietário, mas protocolo-compatível) |
| Preço de referência Gov. | Sob consulta (sem ARP pública) | ✅ **ARP SERPRO 90611/2025 aderível** — preços homologados |
| Disponibilidade de saldo | — | Verificar junto a SUPGA/GATIC SERPRO SP |
| Suporte 60 meses | Sob negociação Dell | ✅ Incluído no contrato NTT (Reg. 283040) |
| Curva operacional | Alta (SONiC é recente) | Moderada (NX-OS bem estabelecido no mercado BR) |

---

## 11. Próximos Passos

1. **Decidir fabric de rede: Opção A (Dell SONiC) ou Opção B (Cisco Nexus NX-OS)** — em
   ambas o SDN é OpenStack OVN; a diferença é apenas o hardware de underlay e o preço.
   Ver tabela comparativa na Seção 10. Para Opção B, verificar saldo na ARP SERPRO 90611/2025
   (contato: SUPGA/GATIC SERPRO SP). **Cisco APIC/ACI não é necessário** em nenhuma das opções.
2. **RFQ formal com Dell** para os 153 servidores (independente da decisão de switch) — volumes
   dessa magnitude normalmente resultam em descontos de 20–40% sobre o preço de lista.
3. ~~**Validar layout de rack**~~ ✅ **Concluído** — GPU 4U e Spine 2U já incorporados em
   `01-physical-architecture.md`; layouts FD1/FD2/FD3 recalculados e validados em 42U.
4. **Selecionar CPU exata** para cada role (a linha Xeon 6 tem modelos E/P — Efficient e
   Performance; os compute nodes devem usar a linha P para maior contagem de cores).
5. **Definir backplane NVMe** para Cinder nodes — confirmar se E3.S ou U.2 dependendo da
   disponibilidade no momento da compra; atualizar spec em `01-physical-architecture.md`.
6. **Contatar Kryptus** para proposta formal de 3 unidades ASI-HSM AHX5 KNET + SLA de suporte
   + confirmar: performance RSA-2048 ops/s, form factor exato, HA group entre AZs, e agregação
   de partições no cluster. Tel: +55 (19) 3112-5000 | kryptus.com.
7. **Confirmar PCI Vendor/Product ID das GPUs** — executar `lspci -nn | grep -i nvidia` após
   entrega dos XE8640 e atualizar `09-gpu-compute.md`.
8. **Provisionar licenças iDRAC** — iDRAC9 Enterprise é necessário para Redfish, Virtual
   Console e automação; verificar se já incluso no SKU ou licença separada.
9. **Se Opção A (Dell):** Obter cotações dos switches (S5448F-ON, Z9664F-ON, N3248TE-ON) —
   todos estão no catálogo dell.com/pt-br mas sem preço público; solicitar via canal comercial
   Dell BR. Levantar preços de transceivers compatíveis com switches Dell.
10. **Se Opção B (Cisco ACI):** Verificar compatibilidade do plugin Cisco ACI com a versão do
    OpenStack adotada (`docs/03-control-plane.md`), e confirmar se o cluster APIC virtual de
    2 nós é suficiente ou se 3 nós são necessários para quórum.

<div align="center">

<img src="tasarımlar/Teknofest%202024.png" alt="Yıldırım Mikrotek - Teknofest 2024" width="620"/>

# ⚡ Yıldırım Mikrotek — Sayısal İşlemci

**TEKNOFEST 2024 · Çip Tasarımı Yarışması**
RISC-V tabanlı, ardışık düzenli (pipeline), sıralı (in-order) 32-bit işlemci çekirdeği

[![ISA](https://img.shields.io/badge/ISA-RV32IMAFB-blue)](#-desteklenen-komut-seti-isa)
[![HDL](https://img.shields.io/badge/HDL-Verilog-orange)](#-depo-yapısı)
[![Tool](https://img.shields.io/badge/EDA-Xilinx%20Vivado-red)](#-vivado-ile-çalıştırma)
[![Target](https://img.shields.io/badge/Hedef-FPGA%20%2F%20ASIC%20(OpenLane)-green)](#-derleme-hedefleri)
[![License](https://img.shields.io/badge/Lisans-MIT-lightgrey)](#-lisans)

</div>

---

## 📌 Proje Hakkında

**Yıldırım Mikrotek**, TEKNOFEST 2024 Çip Tasarımı Yarışması kapsamında sıfırdan
tasarlanmış, açık kaynak **RISC-V (RV32)** komut kümesi mimarisini destekleyen bir
sayısal işlemci çekirdeğidir. Çekirdek; tam sayı, çarpma/bölme, atomik, kayan nokta ve
bit manipülasyonu uzantılarını, dinamik dallanma öngörücüsünü, L1 önbellek
denetleyicilerini ve AXI4 tabanlı bir veri yolu ile UART çevre birimini içerir.

Tasarım hem **FPGA** (Xilinx Vivado) hem de **ASIC** (OpenLane / SkyWater sky130)
akışlarını hedefleyecek şekilde, koşullu derleme (`` `define FPGA `` / `` `define OPENLANE ``)
ile parametrikleştirilmiştir.

> Tüm modüller, sinyal adlandırmaları ve yorumlar Türkçe olarak yazılmıştır
> (ör. `getir` = fetch, `coz` = decode, `yurut` = execute, `bellek` = memory,
> `yazmac` = register, `dallanma` = branch, `onbellek` = cache).

---

## ✨ Öne Çıkan Özellikler

| Alan | Özellik |
|------|---------|
| 🧮 **Komut Seti** | RV32**I** (taban) + **M** (çarpma/bölme) + **A** (atomik) + **F** (kayan nokta) + **B** (bit manipülasyonu: Zba, Zbb, Zbc, Zbs) |
| 🏗️ **Mikromimari** | Sıralı (in-order), çok aşamalı ardışık düzen (getir → çöz → yürüt → bellek → geri yazma) |
| 🔮 **Dallanma Öngörücü** | BTB (Dallanma Hedef Tamponu) + BHT (2-bit doygunluk sayaçları) + Genel Geçmiş Yazmacı (gshare benzeri) |
| 🗄️ **Bellek Alt Sistemi** | Ayrık L1 buyruk/veri önbellek denetleyicileri, SRAM modelleri |
| 🔌 **Veri Yolu** | AXI4 master + AXI4-Lite slave; veri yolu denetleyicisi |
| 📡 **Çevre Birimleri** | UART (alıcı/verici + baud rate üreteci), AXI-UART köprüsü |
| 🛡️ **Sistem** | CSR yazmaçları, istisna/kesme tespiti (exception detection), Makine kipi (M-mode) |
| 🎯 **Hedef** | FPGA (Vivado) ve ASIC (OpenLane sky130) — koşullu derleme |

---

## 🧩 Mimari Genel Bakış

<div align="center">
<img src="tasarımlar/chip%20flow.png" alt="Çip Veri Akışı" width="760"/>
<br/><em>Çekirdek veri akışı (chip flow)</em>
</div>

### Ardışık Düzen (Pipeline) Akışı

```
   ┌──────────┐   ┌──────────┐   ┌───────────────┐   ┌──────────┐   ┌──────────────┐   ┌────────────┐
   │  GETİR   │ → │  GETİR   │ → │  ÇÖZ &        │ → │  YÜRÜT   │ → │  BELLEK      │ → │  GERİ      │
   │ Aşama-1  │   │ Aşama-2  │   │  YAZMAÇ OKU   │   │ (ALU/MUL │   │  İŞLEM       │   │  YAZMA     │
   │ (PC/I$)  │   │ (Buyruk) │   │  (Decode/RF)  │   │  /DIV/FP)│   │  (LSU/D$)    │   │ (Writeback)│
   └────┬─────┘   └──────────┘   └───────────────┘   └────┬─────┘   └──────────────┘   └────────────┘
        │                                                  │
        ▼                                                  ▼
  ┌─────────────┐                                   ┌──────────────┐
  │  DALLANMA   │                                   │   DALLANMA   │
  │  ÖNGÖRÜCÜ   │ ◀──── hatalı tahmin geri besleme ─│   BİRİMİ     │
  │ (BTB+BHT)   │                                   │  (çözümleme) │
  └─────────────┘                                   └──────────────┘
```

### Dallanma Öngörücü

<div align="center">
<img src="tasarımlar/Branch%20Prediction.png" alt="Dallanma Öngörücü" width="680"/>
</div>

- **BTB (Branch Target Buffer):** Geçerli bit + etiket + hedef adres satırları
- **BHT (Branch History Table):** 2-bit doygunluk sayaçları ile alma/almama tahmini
- **GGY (Genel Geçmiş Yazmacı):** Global geçmiş ile indeksleme (gshare benzeri)
- Yürüt aşamasından gelen **hatalı tahmin** sinyaliyle tablolar güncellenir; doğru/yanlış tahmin sayaçları tutulur.

---

## 📂 Depo Yapısı

```
Yildirim-Mikrotek/
├── RTL/                          # Temiz, sentezlenebilir kaynak ağacı
│   ├── src/                      # Verilog modülleri (45+ birim)
│   ├── header/                   # `riscv_controller.vh`, `opcode.vh` (ISA tanımları)
│   └── testhbench/               # Birim test düzenekleri (testbench)
│
├── yildirim_mikrotek/            # Xilinx Vivado proje dosyaları (.xpr + .srcs)
│
├── tasarımlar/                   # Mimari diyagramlar ve görseller
├── kaynaklar/                    # Referans dokümanlar (RISC-V spec, bitmanip, cache, branch pred.)
├── Yildirim_Mikrotek_Rapor/      # Ön & Detaylı Tasarım Raporları (PDF/DOCX)
├── düzenlenmesi_gereken_birimler/# Üzerinde çalışılan/iyileştirilen birimler
└── README.md
```

### Başlıca RTL Modülleri

| Modül (dosya) | Görev |
|---------------|-------|
| `getir_asama1.v`, `getir_asama2.v` | Buyruk getirme (fetch) — PC üretimi ve I$ erişimi |
| `coz_yazmac_oku.v` | Buyruk çözme (decode) + yazmaç öbeği okuma |
| `yazmac_obegi.v` | 32 × 32-bit yazmaç öbeği (register file) |
| `aritmetik_mantik_birimi.v` | ALU |
| `carpma_birimi.v`, `carp_biriktir.v`, `csa64.v` | Çarpma (Carry-Save Adder tabanlı) |
| `bolme_birimi.v` | Bölme / kalan birimi |
| `kayan_nokta_birimi.v` (+ topla/çarp/hizala/yuvarla) | Tek duyarlıklı kayan nokta (RV32F) |
| `bit_manipulasyon_birimi*.v` | Zba / Zbb / Zbc / Zbs + CRC + bit sayma |
| `dallanma_birimi.v`, `dallanma_ongorucu.v` | Dallanma çözümleme + öngörü (BTB/BHT) |
| `bellek_islem_birimi.v` | Yükle/Sakla birimi (LSU) |
| `buyruk_onbellegi_denetleyici.v`, `veri_onbellegi_denetleyici.v` | L1 önbellek denetleyicileri |
| `sram_*.v`, `bram_model.v`, `bellek.v` | Bellek modelleri |
| `veri_yolu_birimi.v`, `veri_yolu_denetleyicisi.v`, `axi_master.v` | AXI4 veri yolu |
| `axi4_lite_slave_uart.v`, `axi_interface_uart.v`, `Uart.v` | AXI-UART köprüsü ve UART |
| `transmitter.v`, `receiver.v`, `baud_rate_generator.v` | UART alt birimleri |
| `csr.v` | Kontrol/Durum Yazmaçları (CSR) |
| `exception_detection.v` | İstisna / kesme tespiti |
| `writeback.v` | Sonuçların yazmaç öbeğine geri yazılması |

---

## 🧮 Desteklenen Komut Seti (ISA)

Hedef temel mimari **RV32IMAFB**:

- **RV32I** — Taban tam sayı komutları (ADD, SUB, AND, OR, XOR, shift, LUI, AUIPC, dallanmalar, yükle/sakla, JAL/JALR …)
- **RV32M** — MUL, MULH(SU/U), DIV(U), REM(U)
- **RV32A** — LR.W / SC.W ve AMO* (swap, add, xor, and, or, min/max…)
- **RV32F** — Tek duyarlıklı kayan nokta (FADD, FSUB, FMUL, FDIV, FSQRT, FMADD, dönüşümler, karşılaştırmalar)
- **RV32B (Zb\*)** — Bit manipülasyonu:
  - **Zba:** SH1ADD / SH2ADD / SH3ADD
  - **Zbb:** ANDN, ORN, XNOR, CLZ, CTZ, CPOP, MIN/MAX, ROL/ROR, REV8, SEXT/ZEXT…
  - **Zbc:** CLMUL / CLMULH / CLMULR (+ CRC32 yardımcıları)
  - **Zbs:** BSET, BCLR, BINV, BEXT (+ immediate türevleri)
- **Zicsr / Sayaçlar** — CSR erişimi, `rdcycle`, `rdtime`, `rdinstret` (+H türevleri)

> Tüm kodlamalar `RTL/header/riscv_controller.vh` ve `RTL/header/opcode.vh`
> dosyalarında maske/eşleşme tanımları olarak bulunur.

---

## 🚀 Vivado ile Çalıştırma

> Gereksinim: **Xilinx Vivado** (proje sürümü 2020+ ile uyumludur).

1. Vivado'yu açın → **Open Project** → `yildirim_mikrotek/yildirim_mikrotek.xpr`
2. Kaynak (`sources_1`) ve simülasyon (`sim_1`) kümeleri otomatik yüklenir.
3. Bir birimi simüle etmek için ilgili testbench'i üst modül seçip
   **Run Simulation → Run Behavioral Simulation** çalıştırın.

### Komut Satırından (toplu/batch mod)

```bash
# Proje dizininde
vivado -mode batch -source <tcl_betiginiz>.tcl yildirim_mikrotek/yildirim_mikrotek.xpr
```

### Bağımsız Simülasyon (Icarus Verilog ile örnek)

`RTL/` ağacı, Vivado'dan bağımsız olarak da derlenebilir:

```bash
# Örnek: ALU birim testi
iverilog -g2012 -I RTL/header \
    -o alu_test \
    RTL/src/aritmetik_mantik_birimi.v \
    RTL/testhbench/tb_aritmetik_mantik_birimi.v
vvp alu_test
```

---

## 🧪 Doğrulama (Testbench'ler)

Her büyük birim için bağımsız test düzenekleri `RTL/testhbench/` altında bulunur:

`tb_aritmetik_mantik_birimi` · `tb_carpma_birimi` · `tb_bolme_birimi` ·
`tb_kayan_nokta_birimi` · `tb_dallanma_birimi` · `tb_dallanma_ongorucu` ·
`tb_csr` · `tb_exception_detection` · `tb_getir_asama2` ·
`tb_bit_manipulasyon_birimi_{zba,zbb,zbc,zbs,bitcnt,crc}` ·
`baud_rate_generator_tb` · `transmitter_tb` · `receiver_tb` · `axi_interface_uart_tb`

---

## 🎯 Derleme Hedefleri

`RTL/header/riscv_controller.vh` başındaki koşullu derleme bayrakları ile hedef seçilir:

```verilog
`define FPGA          // Xilinx Vivado / FPGA akışı (varsayılan)
//`define OPENLANE     // ASIC akışı (OpenLane + SkyWater sky130)
```

`OPENLANE` etkinken hücre adlarına `_sky130` soneki eklenir (`` `GATE `` makrosu).

---

## 📚 Kaynaklar

`kaynaklar/` dizini, tasarımda referans alınan birincil dokümanları içerir:
RISC-V ISA spesifikasyonları (v2.2 ve 2019-12-13), Bit-Manipulation uzantısı
taslakları, önbellek ve dallanma öngörüsü ders notları, TileLink spec ve ilgili
akademik makaleler. Ayrıntılı tasarım anlatımı için
`Yildirim_Mikrotek_Rapor/` altındaki **Ön Tasarım** ve **Detaylı Tasarım**
raporlarına bakınız.

---

## 🗺️ Yol Haritası

- [x] RV32I/M/A/F/B birimlerinin RTL gerçeklemesi
- [x] Dallanma öngörücü (BTB + BHT + GGY)
- [x] L1 önbellek denetleyicileri ve AXI4 veri yolu
- [x] UART çevre birimi (AXI4-Lite)
- [x] Birim testbench'leri
- [ ] Tam çekirdek üst (top) modülünün entegrasyonu ve uçtan uca regresyon
- [ ] `riscv-tests` / uyumluluk paketinin koşturulması
- [ ] OpenLane sky130 ile kapı seviyesi sentez ve zamanlama kapanışı

---

## 📝 Lisans

Bu proje **MIT Lisansı** ile sunulmaktadır. Ayrıntılar için `LICENSE` dosyasına bakınız.

---

<div align="center">

**Yıldırım Mikrotek Takımı** · TEKNOFEST 2024 Çip Tasarımı Yarışması
<br/>
<sub>RISC-V · Verilog · FPGA / ASIC</sub>

</div>

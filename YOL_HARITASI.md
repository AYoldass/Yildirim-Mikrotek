# 🗺️ Yıldırım Mikrotek — RV32IMCA Tamamlama Yol Haritası

> Bu belge, mevcut RTL'in tamamı (46 modül) ve arayüzleri analiz edilerek
> hazırlanmıştır. Amaç: bağımsız birimleri **çalışan bir RV32IMCA çekirdeğine**
> dönüştürmek. Kod yazmadan önceki durum tespiti + uygulama planıdır.
>
> Hedef ISA: **RV32IMCAFB** (taban + çarpma/bölme + sıkıştırılmış + atomik +
> kayan nokta + bit manipülasyon). F ve B birimleri depoda mevcut olduğundan
> bunlar "sıfırdan yaz" değil **entegrasyon** kalemidir (Faz 9).

---

## 1. Mevcut Durum (doğrulandı)

| Konu | Durum |
|------|-------|
| Bağımsız birimler (ALU, MUL, DIV, FPU, bitmanip, CSR, dallanma, L1$, AXI, UART) | ✅ Mevcut, çoğu birim testli |
| **Üst-seviye çekirdek (top) modülü** | ❌ **Yok** — fetch→decode→execute→mem→wb hiçbir yerde bağlanmamış |
| Tek entegrasyon katmanı: `getir_altsistem.v` (getir1+getir2) | ⚠️ Var ama **çalışmıyor** (aşağıya bakınız) |
| Simülatör | ✅ Icarus Verilog 11.0 (`iverilog`, `vvp`) sistemde kurulu |

**Derleme notu:** `getir_asama2.v` içinde `dallanma_ongorucu` örneğinin adı `do`'dur.
`do` SystemVerilog'da ayrılmış kelime olduğundan `-g2012` ile derleme kırılır.
Şu an `-g2005` gerekiyor:
```bash
iverilog -g2005 -I RTL/header -o sim.vvp <tb> <kaynaklar...>
```
→ İleride örnek adı (`do` → `u_dallanma`) düzeltilirse `-g2012` kullanılabilir.

---

## 2. Kritik Bulgular / Tutarsızlıklar

### 🔴 B1 — `getir_asama2` buyruk-teslim veri yolu eksik
`tb_getir_altsistem` çalıştırıldığında FAZ-1 hiç buyruk teslim etmeden takılıyor.
Kök neden (`getir_asama2.v`):
- `l1b_buyruk_i` (bellekten gelen buyruk) port olarak tanımlı ama **gövdede hiç okunmuyor**.
- `coz_buyruk_ns` yalnızca eski değerine atanıyor; yeni buyruğa **asla** set edilmiyor.
- `coz_buyruk_gecerli_ns` yalnızca `0`'a set ediliyor; **asla** `1` olmuyor.
- `buf_buyruk_r/buf_ps_r` tampon kayıtları ve `G2_YAZMAC_YARIM/DOLU` durumları
  tanımlı ama bunları kullanan ana akış **yazılmamış**.

Yani flush/dallanma/duraklatma defter tutması var; asıl "buyruğu yakala → çöze sun"
veri yolu eksik. **Faz 1'in konusu budur.**

### 🟠 B2 — İki ayrı kontrol/çözme (decode) kuşağı
Depoda iki farklı, **birbiriyle uyuşmayan** kodlama şeması var:

| Şema | Kullanan modüller | Kontrol kodlaması |
|------|-------------------|-------------------|
| **A — "klasik"** | `coz_yazmac_oku`, `writeback`, `csr`, `exception_detection` | `opcode_o`(6b) + `mikro_islem`(5b) + `birim_enable`(8b) + ayrık bayraklar (`regwrite`, `memread`…) |
| **B — "mikroislem/birim"** | header (`MI_BIT=28`, `BIRIM_*`, `GERIYAZ_*`, `ALU 14:11`…), `dallanma_birimi` (`islem_kod_i`) | Tek 28-bit mikroislem alanı, bit-alanlı |

`coz_yazmac_oku` şema A'yı üretiyor; `dallanma_birimi` ise şema B'yi bekliyor.
**Entegrasyonda tek bir şema seçilmeli** ve tüm aşamalar ona uydurulmalı.
→ Öneri: Mevcut çöz aşaması zaten şema A'yı üretiyor; **şema A esas alınıp**,
execute-yan birimler için ince "kontrol uyarlama (glue) mantığı" yazmak en az
yeniden-yazma gerektiren yoldur.

### 🟠 B3 — Adres haritası tutarsızlığı
- Getir / `VALID_MEM_START` / testbench tabanı: **0x8000_0000**
- `RAM_BASE_ADDR` / `BELLEK_BASLANGIC` / `veri_yolu_birimi` RAM maskesi: **0x4000_0000**

Tek bir bellek haritasında birleştirilmeli (hangi taban gerçek RAM, hangisi
buyruk bölgesi). UART=0x2000_0000, TIMER=0x3000_0000 tanımları korunur.

### 🟡 B4 — RV32**C** (compressed) tamamen yok
- Getir PC'yi her zaman **+4** artırıyor (`ps_r + 3'd4`); 16-bit / hizasız getir yok.
- 16-bit → 32-bit açan **sıkıştırılmış decoder yok**.
- Yalnızca `dallanma_birimi`'nde `islem_rvc_i` yer tutucusu var.
→ C uzantısı **sıfırdan eklenecek** (decoder + getir hizalama). En büyük yeni iş kalemi.

### 🟡 B5 — RV32**A** (atomic) yürütme birimi yok
- LR.W/SC.W/AMO* **çözme makroları** var (`*_COZ`, `BIRIM_ATOMIC=6`) ama
  bunları **yürüten modül yok**.
→ Atomik birim + LR/SC rezervasyon mantığı + D$ ile etkileşim eklenecek.

### 🟢 B6 — İsim yanıltması: `veri_yolu_denetleyicisi`
Bu modül bir **pipeline veri yolu kontrolcüsü değil**; bellek ile L1B/L1V
önbellek denetleyicileri arasında bir **veri yolu hakemidir (bus arbiter)**.
Çekirdek entegrasyonunda hazard/forwarding için **ayrı bir birim** gerekir.

---

## 3. RV32IMCA Eksik Analizi

| Uzantı | Yürütme birimi | Entegrasyon | Yapılacak |
|--------|----------------|-------------|-----------|
| **I** (taban) | ✅ `aritmetik_mantik_birimi`, çöz `coz_yazmac_oku` | ❌ | Execute/Mem/WB bağlama, hazard/forwarding |
| **M** (mul/div) | ✅ `bolme_birimi` (çok-çevrim); çarpma temiz kombinasyonel | ✅ | Execute'a bağlandı (bkz. Faz 4.5) |
| **C** (compressed) | ✅ `sikistirilmis_cozucu.v` | ✅ | Getir'de açılıyor + hizasız getir (bkz. Faz 7) |
| **A** (atomic) | ✅ `atomik_birim.v` | ✅ | LR/SC rezervasyon + AMO* (bkz. Faz 6) |
| **F** (kayan nokta) | ⚠️ `kayan_nokta_*` BOZUK → temiz `fpu_temiz.v` | ✅ | F yazmaç öbeği + FLW/FSW (bkz. Faz 9) |
| **B** (bitmanip) | ✅ `bit_manipulasyon_*` (draft-B) | ✅ | Execute'a çok-çevrim handshake (bkz. Faz 9) |

---

## 4. Hedef Üst Mimari

```
                         ┌─────────────────────── cekirdek_ust.v ───────────────────────┐
   I$ (L1B + vy)  ◀────▶ │  GETİR(1→2)  →  ÇÖZ+RF  →  YÜRÜT  →  BELLEK  →  GERİ-YAZMA   │ ◀───▶ D$ (L1V + vy)
                         │      │            │          │          │           │         │
                         │   dallanma     hazard /    ALU/MUL/   bellek_     yazmac_     │
                         │   ongorucu    forwarding   DIV/ATOM   islem       obegi       │
                         │      ▲            │       dallanma_     │         CSR/trap     │
                         │      └── hatalı tahmin ── birimi ───────┘                     │
                         └──────────────────────────────────────────────────────────────┘
```

**Yeni yazılacak entegrasyon birimleri:**
1. `cekirdek_ust.v` — tüm aşamaları bağlayan top modül.
2. `tehlike_birimi.v` (hazard) — durdurma (stall) + ileri-besleme (forwarding) +
   flush kontrolü; çok-çevrim birimler (MUL/DIV/FPU) için bekleme.
3. Aşamalar-arası boru hattı kayıtları (her aşama sınırında valid/ready + flush).
4. `coz` çıktısını execute-yan birimlerin beklediği kontrole çeviren glue (B2).
5. (C için) `sikistirilmis_cozucu.v` + getir hizalama mantığı.
6. (A için) `atomik_birim.v` + LR/SC rezervasyon kaydı.

---

## 5. Aşamalı Uygulama Planı

> Her faz **kendi self-checking testbench'i** ile kapanır (iverilog `-g2005`).
> Sıra, riski erken düşürmek ve her adımda çalışan bir şey bırakmak için seçildi.

### Faz 0 — Altyapı kararları (kod azı, karar çok)
- [x] Kontrol/decode şeması kararı (B2) — **ŞEMA B seçildi** (header'daki bit-alanlı
      28-bit mikroislem: `GERIYAZ/YAZMAC/OPERAND/BIRIM/DAL/ALU/BOLME/CARPMA/BIB`).
      Gerekçe: execute-yan birimler (ALU `kontrol_i`, çarpma/bölme `islem`, `dallanma_birimi`,
      `bellek_islem_birimi`) zaten bu alt-alanları tüketiyor; eski `coz_yazmac_oku`
      (şema A) onarılamayacak kadar bozuk olduğundan "az yeniden yazma" avantajı yok.
      Yeni `coz_asamasi.v` şema B üretir.
- [ ] Bellek haritası birleştirme (B3) — tek taban adres. *(Faz 4'te gerekli)*
- [x] `getir_asama2`'deki `do` örnek adını düzelt → `-g2012` uyumu. ✅ (`dal_ongorucu`)
- [x] `sim/` altına ortak iverilog derleme/regresyon betiği (`sim/run_sim.sh`). ✅

### Faz 1 — Getir alt sistemini bitir ⭐ ✅ TAMAMLANDI
- [x] `getir_asama2` **temiz yeniden yazıldı**: (PS, buyruk) çifti eşleştirme,
      valid/ready el-sıkışması, dallanma öngörü + yönlendirme, duraklatma, flush.
- [x] Çözülen 2 kök hata: (1) eksik buyruk-teslim veri yolu (B1);
      (2) `always@*` içinde kendi çıkış kablosunu okuyarak oluşan, iverilog'da
      yakınsamayan delta-döngüsü (g1 ve g2'de). Artık yalnızca kayıt+giriş kaynaklı.
- [x] `tb_getir_altsistem` FAZ-1 (sıralı) + FAZ-2 (öngörü döngüsü) **GEÇTİ** ✅
      (`./sim/run_sim.sh` → 1/1 geçti, `-g2012`).

### Faz 2 — Çöz aşaması entegrasyonu ✅ TAMAMLANDI
- [x] Eski `coz_yazmac_oku` onarılamaz bulundu (rs1/rs2_addr atanmıyor, yanlış RF
      portları, `opcode_o` taşması, geçersiz `case`'ler). Yerine temiz **`coz_asamasi.v`**
      yazıldı: şema B mikroislem üretir, `yazmac_obegi` (scoreboard RF) doğru bağlanır,
      anlık üretir, operand seçer (REG/IMM/PC/PCIMM), coz→yurut kaydı (durdur/bosalt).
- [x] RV32I + RV32M tam ve doğru çözülüyor (A/F/B/CSR/C kendi fazlarında).
- [x] `tb_coz_asamasi` (12 buyruk, 50+ alan kontrolü) **GEÇTİ** ✅
- [x] `tb_getir_coz` (getir→coz entegrasyon, sıralı akış + temel çözüm) **GEÇTİ** ✅
- [x] Regresyon: `./sim/run_sim.sh` → 3/3 geçti.

### Faz 3 — Yürüt aşaması + hazard ✅ TAMAMLANDI (çekirdek veri yolu)
- [x] `yurut_asamasi.v`: ALU (`aritmetik_mantik_birimi`) + dallanma çözümleme
      (`dallanma_birimi`) + geri-yazma seçimi (GERIYAZ) + öngörücü eğitimi +
      yanlış-tahmin yönlendirmesi. (Bu fazda yürüt = geri-yazma; ayrı bellek
      aşaması ve çok-çevrimli birimler sonraki adımda.)
- [x] **Hazard interlock = scoreboard tabanlı stall** (forwarding yerine, daha
      basit/doğru): `coz` kaynak geçerli değilse `durdur` + getir dondurulur,
      aşağıya kabarcık; üretici geri yazınca (etiket eşleşmesi) tüketici yayınlanır.
      WAW da etiket sayacı ile doğru ele alınır.
- [x] Dallanma çözümleme → öngörücü geri besleme + yanlış tahminde flush+yönlendir.
- [x] **`cekirdek.v` üst modülü**: getir→coz→yurut + RF + hazard tam bağlı.
- [x] **`tb_cekirdek`** uçtan uca (RAW bağımlılık zinciri + alınan dallanma + JAL)
      → 11/11 son register doğru. Regresyon: `./sim/run_sim.sh` → 4/4 geçti.

> **Fetch notu:** Entegre çekirdek `getir_basit.v` (kombinasyonel buyruk belleği,
> temiz stall/flush) kullanır — `getir_altsistem`'in ayrık PC/buyruk boru hatları
> backpressure+flush altında skid-buffer+drain gerektiriyor (yarım kalmış); bu
> "gelişmiş fetch" iyileştirmesi ileriye bırakıldı (Faz 1 testi hâlâ geçiyor).
>
> **Bu fazda ertelenenler:** MUL/DIV geri-yazması (GERIYAZ_CARP, çok-çevrim
> handshake) ve load/store (Faz 4 bellek aşaması) — yürüt iskeleti hazır.

### Faz 4 — Bellek aşaması ✅ TAMAMLANDI (load/store)
- [x] `bellek_islem_birimi` (LSU) yürüt aşamasına bağlandı: adres=rs1+imm (ALU),
      maske + hizalı store verisi; yük için byte hizalama + işaret/sıfır genişletme.
- [x] `cekirdek.v` veri belleği arayüzü (kombinasyonel okuma, senkron maskeli yazma).
      Load-use, execute=writeback modelinde scoreboard ile zaten doğru (ekstra mantık yok);
      store→load sıralı bütünlüğü korunur.
- [x] `tb_cekirdek` genişletildi: LW/SW, LH/LHU/SH, LB/LBU/SB + işaret/sıfır genişletme +
      bellek içeriği doğrulandı → 18 register + bellek kontrolü GEÇTİ. Regresyon 4/4.
- [ ] (İleri) Gerçek L1V denetleyici + `veri_yolu_birimi`/AXI bağlama (şimdilik düz bellek).

### Faz 4.5 — M uzantısı tamamlama (MUL/DIV geri-yazma) ✅ TAMAMLANDI
- [x] **CARPMA (MUL/MULH/MULHU/MULHSU):** yürüt içinde **temiz kombinasyonel** 64-bit
      çarpım (1 çevrim, ALU gibi). Depodaki `carpma_birimi.v` bir MAC çekirdeği olup
      iç biriktiricisi yalnızca rst ile temizleniyor (ayrık MUL'lar arası sıfırlanmıyor)
      → ardışık çarpmalarda yanlış; bu yüzden entegre EDİLMEDİ, temiz çarpımla değiştirildi.
- [x] **BOLME (DIV/DIVU/REM/REMU):** `bolme_birimi.v` (gerçek çok-çevrimli, ~18 çevrim)
      `bitti_o` handshake ile bağlandı. `result_o` yalnızca tamamlanma çevriminde geçerli
      → operandlar yakalanıp sabitlenir, `start_i` işlem boyunca yüksek tutulur, sonuç
      `bitti_o` darbesinde geri yazılır. `rst_i` AKTİF-YÜKSEK olduğundan `~rst_i` verilir.
- [x] **Çok-çevrim stall:** yürüt `mesgul_o` üretir; `cekirdek.v`'de `durdur = hazard || mesgul`
      → getir+çöz dondurulur, sonraki buyruk yayınlanmaz; tamamlanınca serbest + geri yaz.
      Cok-cevrim sonucuna RAW bağımlılık scoreboard ile zaten doğru (üretici geri yazınca
      tüketici yayınlanır).
- [x] **`tb_cekirdek_m`** uçtan uca: MUL/MULH/MULHU/MULHSU + DIV/DIVU/REM/REMU, işaretli,
      sıfıra bölme/mod, çok-çevrim sonucuna RAW + ardışık bölmeler → 18/18 GEÇTİ.
      Regresyon `./sim/run_sim.sh` → 5/5 geçti.

### Faz 5 — CSR + trap ✅ TAMAMLANDI
- [x] Depodaki `csr.v`/`writeback.v`/`exception_detection.v` **şema A** (one-hot
      `opcode_i[\`LOAD]`, `birim_enable_i[\`BIRIM_CSR]`, bit-indeksli `mikro_islem_i`,
      ayrı writeback-stage PC kontrolü) → şema B + execute=writeback modeline uymuyor.
      Önceki örüntüye uygun: temiz **`csr_birimi.v` (şema B)** yazıldı (csr.v'nin doğru
      CSR semantiği korunarak).
- [x] **CSR'ler:** misa, mstatus(MIE/MPIE/MPP), mie, mip, mtvec, mscratch, mepc,
      mcause, mtval, mcycle(+h), minstret(+h), mcountinhibit.
- [x] **CSR buyrukları:** CSRRW/CSRRS/CSRRC + immediate türevleri (CSRRWI/SI/CI).
      Eski değer rd'ye (yurut `BIRIM_CSR` ile seçer), yeni değer op'a göre CSR'ye.
      RS/RC'de kaynak=0 ise yazma yok (yan etki bastırma).
- [x] **Trap/dönüş:** ECALL/EBREAK/illegal → mtvec'e tuzak (mepc=PC, mcause kodu,
      mstatus.MIE→MPIE); MRET → mepc'e dönüş (MIE geri yükle). Yönlendirme+boşaltma
      mevcut dallanma yanlış-tahmin mekanizmasıyla aynı (yurut `csr_trap` önceliklidir).
      Yeni mikroislem alanı `SYS 24:22` (ECALL/EBREAK/MRET/ILLEGAL); coz SYSTEM çözer.
- [x] Kesme altyapısı (mstatus/mie/mip + dış/zaman/yazılım) mevcut; bu fazda kesme
      kaynağı yok → girişler 0'a bağlı (kesme tetiklenmez). Senkron istisna + mret tam test.
- [x] **`tb_cekirdek_csr`**: mtvec/mscratch yaz-oku (eski/yeni değer), ECALL→handler,
      mcause=11 + mepc=ECALL PC, handler mepc+=4 → MRET dönüşü doğrulandı, mcycle sayıyor
      → 9/9 GEÇTİ. Regresyon `./sim/run_sim.sh` → 6/6 geçti.

### Faz 6 — A uzantısı (atomik) ✅ TAMAMLANDI
- [x] **`atomik_birim.v`** (sıfırdan): LR.W/SC.W + AMO* (SWAP/ADD/XOR/AND/OR/MIN/MAX/
      MINU/MAXU). funct5 = buyruk[31:27]; adres = rs1 (offset yok), kaynak = rs2.
- [x] **Tek-çevrim RMW:** çekirdeğin veri belleği kombinasyonel-okuma + senkron-yazma
      olduğundan AMO ve LR/SC tek çevrimde biter — eski değer kombinasyonel okunur (rd'ye),
      yeni değer aynı posedge'de yazılır. Çok-çevrim/handshake GEREKMEZ. Ardışık aynı-adres
      atomikler doğru (senkron yazma sonraki kombinasyonel okumadan önce tamamlanır).
- [x] **LR/SC rezervasyonu** (tek-hart): LR adresi rezerve eder (rez_gecerli_r+rez_adres_r);
      SC yalnızca geçerli+adres-eşleşen rezervasyonda başarır (rd=0), sonra temizler; AMO da
      temizler. SC başarısız → rd=1, yazma yok. (Çok-hart/normal-store çakışması kapsam dışı.)
- [x] **Yürüt entegrasyonu:** `atomik_mi` (BIRIM_ATOMIC) ile bellek arayüzü mux'lanır
      (adres=rs1, maske=word), rd kaynağı atomik birimden; LSU ile karşılıklı dışlamalı.
      coz ATOMIC opcode'unu çözer (BIRIM_ATOMIC, OPERAND_REG, YAZMAC_YAZ).
- [x] **`tb_cekirdek_a`**: AMOADD/SWAP/OR/AND/MIN/MAX (eski değer + bellek evrimi),
      LR/SC başarı (rd=0) + rezervasyonsuz SC başarısız (rd=1) → 14/14 GEÇTİ.
      Regresyon `./sim/run_sim.sh` → 8/8 geçti.

### Faz 7 — C uzantısı (sıkıştırılmış) ✅ TAMAMLANDI
- [x] **`sikistirilmis_cozucu.v`** (16-bit → 32-bit genişletme): tam RV32C tamsayı
      kümesi — Q0 (ADDI4SPN/LW/SW), Q1 (ADDI/JAL/LI/LUI/ADDI16SP/SRLI/SRAI/ANDI/
      SUB/XOR/OR/AND/J/BEQZ/BNEZ), Q2 (SLLI/LWSP/JR/MV/EBREAK/JALR/ADD/SWSP).
      F/D ve RV64 (C.*W) → `gecersiz_o`. 16 buyruk bilinen RV32I genişletmesine karşı
      tek tek doğrulandı.
- [x] **Getir hizalama:** `getir_basit` `bel_buyruk_i`'yi byte-adresinden başlayan 32 bit
      kabul eder (testbench half-word granüler bellek). `buyruk[1:0]!=11` → sıkıştırılmış,
      açılır, **PC += 2**; aksi halde 32-bit, **PC += 4**. Sınır-aşan (straddle) 32-bit
      buyruk doğal olarak çalışır (32 bit byte-adresinden okunur).
- [x] **rvc bayrağı** getir→coz→yurut→`dallanma_birimi.islem_rvc_i` taşınır → JAL/JALR
      bağlantısı ve dal "atlanmadı" yolu sıkıştırılmışta **PC+2** (32-bit'te PC+4).
- [x] 32-bit-only kod için davranış aynı (regresyon 6/6 değişmedi); RVC eklemesi şeffaf.
- [x] **`tb_cekirdek_rvc`**: karışık C/32-bit akış, straddle, tüm aritmetik/mantık/kaydırma
      compressed formlar, yük/sakla, c.j/c.jal(link=PC+2)/c.beqz/c.bnez → 15/15 GEÇTİ.
      Regresyon `./sim/run_sim.sh` → 7/7 geçti.
- [ ] (İleri) Sıkıştırılmış decoder'ı da `getir_altsistem` boru hatlı getir'e taşımak;
      dallanma öngörücüyü 2-byte hizalı PC için ayarlamak (şu an redirect ile doğru).

### Faz 8 — Uçtan uca regresyon + SoC (bellek + çevresel + kesme) ✅ TAMAMLANDI
- [x] **Çoklu-uzantı entegrasyon testi** `tb_cekirdek_karma`: tek programda I+M+B+F+A+CSR
      birlikte — geriye dallanmalı döngü (kareler toplamı = MUL+ADD+dallanma öngörü/redirect),
      DIV (ortalama), CPOP (B), FCVT.S.W+FMUL (F), AMOADD (A), mcycle (CSR) — uzantılar-arası
      hazard/scoreboard/mesgul etkileşimleri doğrulanır → 12/12 GEÇTİ.
- [x] **SoC üst modülü `cekirdek_ust.v`**: çekirdek + RAM (kelime-granüler, komb. okuma/senk.
      yazma) + memory-mapped çevresel birimler. Adres haritası: RAM 0x8000_0000; çevre 0x1000_0000
      (UART_TX/durum, MTIME/MTIMECMP, TOHOST).
- [x] **Çevresel birimler:** UART TX (yaz→bayt + durum/busy), **zamanlayıcı** (mtime her çevrim
      artar, mtimecmp; `zaman_kesme = mtime>=mtimecmp`), **tohost** (yaz→program biter + çıkış kodu).
- [x] **Kesme yolu (Faz 5'te test edilmemişti):** çekirdeğe kesme giriş portları eklendi
      (dis/zaman/yazılım); zamanlayıcı kesmesi → mip.MTIP → trap. **Precise interrupt**: CSR `tuzak_o`
      ile execute'taki buyruk squash edilir (commit/mem/çok-çevrim başlatma bastırılır), mepc=buyruk PC,
      mret sonrası yeniden çalışır. `tb_cekirdek_ust`: "Hi" UART çıkışı + zamanlayıcı kesmesi
      handler'da işlenir (x20=1, mtimecmp kapatılır, mret) + tohost ile sonlandırma → GEÇTİ.
- [x] **Sistem yolu (bus) + bekleme-durumu:** `sistem_yolu.v` — çekirdeğin buyruk-getirme ve
      veri portlarını adres çözümüyle (adres[31:28]) RAM (0x8…) ve çevre (0x1…) slave'lerine
      bağlar. **RAM_GECIKME ile RAM veri erişimine bekleme-durumu (wait-state)** verilir; çekirdek
      bunu doğru tolere eder: yürüt `mem_bekle_o`, çöz `dondur_i` (y_*'ı bubble yerine TUT),
      commit (int/float wb + bellek yazma) bellek hazır olunca serbest. Buyruk-getirme tek çevrim.
      Çekirdeğe `veri_hazir_i` portu eklendi (tüm tb'ler 1'e bağlandı → davranış değişmedi).
- [x] `cekirdek_ust` artık `cekirdek + sistem_yolu`. `tb_cekirdek_ust` RAM_GECIKME=2 ile:
      UART "Hi" + **RAM'e bekleme-durumlu store/load** (RAW) + zamanlayıcı kesmesi + tohost → GEÇTİ.
- [x] Regresyon `./sim/run_sim.sh` → **12/12 geçti**.
- [x] **Gerçek `veri_yolu_birimi` bağlandı:** `soc_veriyolu.v` = çekirdek → `veri_yolu_kopru`
      (köprü) → **`veri_yolu_birimi`** (depodaki gerçek bus FSM: HAZIR/ISTEK/BEKLE) → `port_bellek`
      (port-protokollü RAM, 1-çevrim okuma gecikmesi + buyruk okuma portu). Köprü, çekirdeğin
      tutulan-istek + `veri_hazir_i` arayüzünü bus'ın transaction'lı `bib` protokolüne çevirir
      (tek anda tek işlem; okumada `bellek_gecerli` darbesi, yazmada `bellek_hazir`). `tb_soc_veriyolu`:
      gerçek bus üzerinden yük/sakla/aritmetik + RAW bağımlılık + lh/lbu → GEÇTİ. Regresyon 13/13.
- [x] **L1 veri önbelleği UÇTAN UCA ÇALIŞIYOR (tam bellek hiyerarşisi):**
      `soc_l1.v` = çekirdek → köprü → `veri_yolu_birimi` → **`veri_onbellegi_denetleyici`**
      (2-yollu write-back) → { `l1_sram` (tag+blok BRAM), `ana_bellek` (vy/alt-seviye) }.
      Veri 0x4000_0000 bölgesinde (önbelleklenebilir). Yeni modüller: `l1_sram.v`, `ana_bellek.v`.
      - **Kök neden (çözüldü):** `veri_yolu_birimi` (vyb) ile `veri_onbellegi_denetleyici` (L1)
        `always@*` blokları arasında, port el-sıkışma sinyalleri (port_istek_hazir,
        port_veri_hazir, **port_veri_gecerli/port_veri**) KOMBİNASYONEL sürüldüğünde gerçek bir
        kombinasyonel çevrim oluşuyordu. Değerler kararlı-noktaya otursa bile iverilog iki bloğu
        sonsuz event-pingpongunda döndürüp simülasyon zamanını donduruyordu (donanımda da hatalı).
      - **Düzeltme:** vyb↔L1 sınırındaki el-sıkışma yönleri KAYDEDİLDİ:
        `port_istek_hazir_o = port_istek_hazir_r` (L1), `port_veri_hazir_o = port_veri_hazir_r` (vyb).
        Cached HIT okuma yanıtı kombinasyonel (`port_veri_gecerli_cmb=1`) yerine, depodaki kayıtlı
        **L1_YANIT** durumuna yönlendirildi (uncached yolun zaten kullandığı gecerli/hazir +
        tüketimde-temizle el-sıkışması); `port_veri_o/port_veri_gecerli_o = *_r`. İç mantık yine
        `_ns` kullandığından veri yakalama doğru çevrimde olur (yalnızca 1 çevrim kayıtlı gecikme).
      - **Doğrulandı:** `tb_soc_l1` 4/4 — store/load miss→allocate→hit, aynı satıra 3. etiket →
        EVICTION (kirli yol write-back) + yeniden getir → x3=0xAA, x4=0xBB, x5=0xAA(evict), x6=0xDD.
        Regresyona EKLENDİ; `./sim/run_sim.sh` → **14/14**. (vyb değişikliği soc_veriyolu'nu bozmadı.)
- [ ] (İleri) Gerçek `riscv-tests` (toolchain gerekir). `veri_yolu_denetleyicisi` (bus hakemi),
      gerçek seri UART (`Uart.v`/`transmitter`, baud) + PLIC dış kesme FPGA için.

### Faz 9 — F ve B uzantı entegrasyonu ✅ TAMAMLANDI
- [x] **B:** `bit_manipulasyon_birimi` (tam draft-B birimi, kendi içinde buyruğu çözer,
      valid/ready handshake'li) execute'a **çok-çevrim handshake** ile bağlandı (DIV/B ortak
      `mesgul` altyapısı). coz, taban/M ile çakışmayan B alt-kümesini tespit edip yönlendirir
      (yeni `BMANIP` mikroislem biti): ANDN/ORN/XNOR, MIN/MAX/U, ROL/ROR/RORI, CLZ/CTZ/CPOP/
      SEXT.B/H, SH1/2/3ADD, CLMUL. **M tespiti `bit25` yerine tam funct7'ye düzeltildi**
      (B'nin 0000101 funct7'si bit25=1 olduğundan M ile karışıyordu). `tb_cekirdek_b` 20/20.
- [x] **F:** Depodaki `kayan_nokta_birimi` ve alt modülleri **BOZUK** (hizalama modülü çift
      bildirim+çoklu sürücü; çarpma var-olmayan `enyuksek_sol_bit48`'e bağlı) → sadık entegre
      edilemez. Önceki örüntüye uygun temiz **`fpu_temiz.v`** yazıldı (kombinasyonel, RNE):
      FADD/FSUB/FMUL, FSGNJ[N/X], FMIN/FMAX, FEQ/FLT/FLE, FCVT.W.S/WU + S.W/S.WU, FMV.X.W/W.X,
      FCLASS. (FMADD/altnormaller kapsam dışı.)
- [x] **FDIV.S + FSQRT.S eklendi** (2026-06-07): `fpu_temiz`'e tam-hassas **kombinasyonel**
      bölme (24-bit mantis, ma/mb·2²⁷ tamsayı bölme → normalize + RNE; kalan→sticky) ve karekök
      (tek/çift üs ayrımı + bit-bit digit-recurrence isqrt, 26-bit → RNE) işlevleri. FPU zaten
      kombinasyonel olduğundan **çok-çevrim handshake gerekmedi**; coz'da FDIV `fpu_fsrc2`'ye
      eklendi (f[rs2] okur). Birim test 12/12 (1/3, √2, √0.5 RNE doğru). `tb_cekirdek_fdiv`
      7/7: çekirdek üzerinden decode yönlendirme + F scoreboard RAW (√8 ← fdiv sonucu) doğrulandı.
- [x] **F altyapısı:** `fp_yazmac_obegi.v` (f0-f31, f0 sıfır-sabit DEĞİL, scoreboard);
      FLW/FSW (bellek↔f-reg, LSU yeniden kullanılır); F kaynak/hedef sınıflandırması coz'da
      (tamsayı↔float karışık operandlar); F hazard scoreboard'a eklendi; float geri-yazma yolu.
      FPU tek-çevrim (kombinasyonel) → çok-çevrim gerekmez; F-reg RAW scoreboard ile doğru.
- [x] **FCSR (yuvarlama modları):** rm alanından (funct3) **statik yuvarlama modları**
      RNE/RTZ/RDN/RUP/RMM eklendi (ortak `round_up` fonksiyonu: guard/round/sticky/lsb/işaret).
      FADD/FSUB/FMUL/FDIV/FSQRT/FCVT.S.W bu modu uygular. `tb_fpu_yuvarlama` 15/15 (1/3 tüm
      modlar, -1/3 işaret duyarlı RDN/RUP, √2 RUP farkı). **DYN(111)→RNE** (frm CSR henüz bağlı
      değil — ileri iş); FCVT.W.S hâlâ RTZ kesme; istisna bayrağı (fflags) biriktirme yok.
- [x] **`tb_cekirdek_f`** 14/14: FLW/FSW, FADD/FSUB/FMUL (FLW sonucuna RAW), FEQ/FLT, FCVT
      (çift yön), FMV.X.W, FSGNJN, FMIN + bellek geri-yazma. Regresyon `./sim/run_sim.sh` → 10/10.

### Faz 10 — (Opsiyonel) Sentez
- [ ] Vivado sentez + OpenLane sky130 akışı, zamanlama kapanışı.

---

## 6. Doğrulama Stratejisi
- **Her faz** kendi iverilog self-checking testbench'i ile kapanır; regresyon
  betiği tüm geçmiş testleri tekrar koşar (geri gidiş olmasın).
- Entegrasyon testbench'leri kademeli büyür (getir → getir+çöz → +yürüt …).
- Nihai doğrulama: `riscv-tests` ELF/hex'lerini bellek modeline yükleyip
  `tohost` ile başarı/başarısızlık yakalama.

---

## 7. Açık Kararlar (kullanıcı onayı gerekebilir)
1. **Kontrol şeması (B2):** Şema A (mevcut çöz) esas alınsın mı, yoksa header'daki
   28-bit mikroislem şemasına (B) mı geçilsin?
2. **Bellek haritası (B3):** Gerçek RAM tabanı `0x8000_0000` mı `0x4000_0000` mı?
3. **C/A önceliği:** IMCA için C ve A şart; F/B bu turda kapsam dışı bırakılsın mı?
4. **Hedef akış:** Önce FPGA (Vivado) mı, yoksa sadece iverilog regresyon mu?
```

> Önerilen başlangıç: **Faz 0 kararları → Faz 1 (getir alt sistemini çalışır hale getir)**.
> Faz 1, tek başına test edilebilir somut bir kazanım ve gerisinin temeli.

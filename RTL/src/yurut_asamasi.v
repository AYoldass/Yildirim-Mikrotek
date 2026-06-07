`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  yurut_asamasi  -  Yurut (Execute) Asamasi
// ---------------------------------------------------------------------------
//  coz asamasindan gelen (kayitli) mikroislem ve operandlar ile islemi yapar.
//  Bu surumde yurut AYNI ZAMANDA geri-yazma (writeback) gorevini gorur: ALU /
//  CARPMA / yuk verisi / baglanti adresi dogrudan yazmac obegine yazilir (RF
//  yazmasi RF icinde kayitlidir).
//
//  Kapsam:
//    - RV32I ALU/LUI/AUIPC + kosullu dallanma + JAL/JALR  (kombinasyonel, 1 cevrim)
//    - RV32M CARPMA (MUL/MULH/MULHU/MULHSU)               (kombinasyonel, 1 cevrim)
//    - RV32M BOLME  (DIV/DIVU/REM/REMU)                   (cok-cevrimli, ~18 cevrim)
//    - Bellek (LSU): yuk/sakla                            (kombinasyonel okuma)
//
//  CARPMA NOTU: Depodaki carpma_birimi.v bir MAC (carp-biriktir) cekirdegidir;
//  ic birikitiricisi (biriktirici) yalnizca rst ile temizlenir, ayrik MUL
//  buyruklari arasinda sifirlanmaz -> ardisik carpmalarda yanlis sonuc verir.
//  Bu yuzden ayrik RV32M carpmasi burada TEMIZ KOMBINASYONEL 64-bit carpim ile
//  yapilir (sentezde DSP'ye eslesir). Eski kirilgan birim entegre edilmedi.
//
//  BOLME NOTU: bolme_birimi.v cok-cevrimli gercek bir bolucudur; result_o
//  YALNIZCA tamamlanma cevriminde (bitti_o=1) gecerlidir. Bu yuzden start_i
//  islem boyunca yuksek tutulur, operandlar yakalanip sabitlenir ve sonuc
//  bitti_o darbesinde geri yazilir. Islem suresince mesgul_o yukselir;
//  ust modul bununla getir+coz'u dondurur (ardisik duzen duraklatma).
//
//  rst_i AKTIF-DUSUK.
// ===========================================================================

module yurut_asamasi (
   input                          clk_i,
   input                          rst_i,

   // --- coz asamasindan (kayitli) ---
   input   [31:0]                 yurut_ps_i,
   input   [31:0]                 yurut_deger1_i,
   input   [31:0]                 yurut_deger2_i,
   input   [31:0]                 yurut_rs2_deger_i,
   input   [31:0]                 yurut_imm_i,
   input   [`MI_BIT-1:0]          yurut_mikroislem_i,
   input   [31:0]                 yurut_buyruk_i,
   input   [31:0]                 yurut_fdeger1_i,
   input   [31:0]                 yurut_fdeger2_i,
   input   [31:0]                 yurut_fdeger3_i,
   input   [4:0]                  yurut_rd_adres_i,
   input   [3:0]                  yurut_etiket_i,
   input                          yurut_gecerli_i,
   input                          yurut_atladi_i,
   input                          yurut_rvc_i,

   // --- Kesme kaynaklari (bu fazda 0) ---
   input                          dis_kesme_i,
   input                          zaman_kesme_i,
   input                          yazilim_kesme_i,

   // --- Yazmac obegine geri yazma ---
   output  [4:0]                  wb_yaz_adres_o,
   output  [31:0]                 wb_yaz_veri_o,
   output  [3:0]                  wb_yaz_etiket_o,
   output                         wb_yaz_gecerli_o,

   // --- Cok-cevrimli birim mesgul (ust modul getir+coz'u dondurur) ---
   output                         mesgul_o,

   // --- Kayan nokta (F) yazmac obegine geri yazma ---
   output  [4:0]                  fwb_yaz_adres_o,
   output  [31:0]                 fwb_yaz_veri_o,
   output  [3:0]                  fwb_yaz_etiket_o,
   output                         fwb_yaz_gecerli_o,

   // --- Veri bellegi arayuzu (kombinasyonel okuma; mem_hazir_i=0 -> bekleme) ---
   output  [31:0]                 mem_adres_o,
   output                         mem_oku_o,
   output                         mem_yaz_o,
   output  [31:0]                 mem_veri_o,
   output  [3:0]                  mem_maske_o,
   input   [31:0]                 mem_veri_i,
   input                          mem_hazir_i,    // 0: bellek mesgul -> bu buyrugu dondur
   output                         mem_bekle_o,    // bellek bekleniyor (ust modul dondurur)

   // --- Getir: dallanma ongorucu egitimi ---
   output  [31:0]                 egit_ps_o,
   output  [31:0]                 egit_hedef_ps_o,
   output                         egit_guncelle_o,
   output                         egit_atladi_o,
   output                         egit_hatali_tahmin_o,

   // --- Getir: yanlis tahmin yonlendirmesi ---
   output  [31:0]                 yonlendir_ps_o,
   output                         yonlendir_gecerli_o,

   // --- Ardisik duzen bosaltma (yanlis tahmin) ---
   output                         bosalt_o
);

   wire [3:0] alu_kod = yurut_mikroislem_i[`ALU];
   wire [2:0] birim   = yurut_mikroislem_i[`BIRIM];
   wire [3:0] dal_kod = yurut_mikroislem_i[`DAL];
   wire [1:0] geriyaz = yurut_mikroislem_i[`GERIYAZ];
   wire       yazmac  = yurut_mikroislem_i[`YAZMAC];
   wire [1:0] carp_kod= yurut_mikroislem_i[`CARPMA];
   wire [1:0] bol_kod = yurut_mikroislem_i[`BOLME];

   // ---------------- ALU ----------------
   wire [31:0] alu_sonuc;
   aritmetik_mantik_birimi alu (
      .kontrol_i ( alu_kod        ),
      .value1_i  ( yurut_deger1_i ),
      .value2_i  ( yurut_deger2_i ),
      .result_o  ( alu_sonuc      )
   );

   // ---------------- Carpma (RV32M) : temiz kombinasyonel ----------------
   wire [63:0] carp_uu = yurut_deger1_i * yurut_deger2_i;                 // u x u
   wire signed [63:0] carp_ss =
        $signed({{32{yurut_deger1_i[31]}}, yurut_deger1_i}) *
        $signed({{32{yurut_deger2_i[31]}}, yurut_deger2_i});              // s x s
   wire signed [63:0] carp_su =
        $signed({{32{yurut_deger1_i[31]}}, yurut_deger1_i}) *
        $signed({32'b0, yurut_deger2_i});                                 // s x u
   reg [31:0] carp_sonuc;
   always @* begin
      case (carp_kod)
         `CARPMA_MUL:    carp_sonuc = carp_uu[31:0];
         `CARPMA_MULH:   carp_sonuc = carp_ss[63:32];
         `CARPMA_MULHSU: carp_sonuc = carp_su[63:32];
         `CARPMA_MULHU:  carp_sonuc = carp_uu[63:32];
         default:        carp_sonuc = carp_uu[31:0];
      endcase
   end

   // ---------------- Bolme (RV32M) : cok-cevrimli handshake ----------------
   wire bol_istek = yurut_gecerli_i && (birim == `BIRIM_BOLME);

   reg         mc_aktif_r;       // bir bolme islemi devam ediyor
   reg [31:0]  mc_d1_r, mc_d2_r; // yakalanan operandlar (sabitlenir)
   reg [1:0]   mc_op_r;          // BOLME kodu
   reg [4:0]   mc_rd_r;          // hedef yazmac
   reg [3:0]   mc_etiket_r;      // writeback etiketi
   reg         mc_yaz_r;         // rd'ye yaziyor mu

   wire        mc_baslat = bol_istek && !mc_aktif_r && !csr_tuzak; // tuzakta baslatma
   wire        div_start = mc_baslat || mc_aktif_r;    // bolucuye start_i

   // Baslatma cevriminde operandlar y_* (mc_aktif_r=0); sonra yakalanmis mc_*.
   wire [31:0] div_a  = mc_aktif_r ? mc_d1_r : yurut_deger1_i;
   wire [31:0] div_b  = mc_aktif_r ? mc_d2_r : yurut_deger2_i;
   wire [1:0]  div_op = mc_aktif_r ? mc_op_r : bol_kod;

   wire [31:0] div_sonuc;
   wire        div_bitti;

   bolme_birimi bol (
      .clk_i     ( clk_i      ),
      .rst_i     ( ~rst_i     ),         // bolme_birimi rst AKTIF-YUKSEK
      .start_i   ( div_start  ),
      .islem_i   ( div_op     ),
      .bolunen_i ( div_a      ),
      .bolen_i   ( div_b      ),
      .result_o  ( div_sonuc  ),
      .bitti_o   ( div_bitti  )
   );

   wire div_tamam = mc_aktif_r && div_bitti;   // tamamlanma cevrimi

   always @(posedge clk_i) begin
      if (!rst_i) begin
         mc_aktif_r <= 1'b0;
      end
      else if (mc_baslat) begin
         mc_aktif_r  <= 1'b1;
         mc_d1_r     <= yurut_deger1_i;
         mc_d2_r     <= yurut_deger2_i;
         mc_op_r     <= bol_kod;
         mc_rd_r     <= yurut_rd_adres_i;
         mc_etiket_r <= yurut_etiket_i;
         mc_yaz_r    <= (yazmac == `YAZMAC_YAZ) && (yurut_rd_adres_i != 5'd0);
      end
      else if (div_tamam) begin
         mc_aktif_r <= 1'b0;
      end
   end

   // ---------------- Bit-manipulasyon (RV32B) : cok-cevrimli handshake -------
   //  bit_manipulasyon_birimi valid/ready el-sikismali; sonuc dout_valid'de
   //  gecerli. DIV gibi: baslatta din_valid darbesi, kabulde aktif, dout_valid'de
   //  geri yaz. (Yalnizca coz'un yonlendirdigi cozulebilir B buyruklari gelir.)
   wire bmanip_mi = yurut_gecerli_i && yurut_mikroislem_i[`BMANIP];

   reg         mc_b_aktif_r;
   reg [4:0]   mc_b_rd_r;
   reg [3:0]   mc_b_etiket_r;
   reg         mc_b_yaz_r;

   wire        b_baslat   = bmanip_mi && !mc_b_aktif_r && !csr_tuzak;
   wire        b_din_rdy, b_dout_valid;
   wire [31:0] b_result;
   wire        b_kabul    = b_baslat && b_din_rdy;       // birim girisi kabul etti
   wire        b_tamam    = mc_b_aktif_r && b_dout_valid; // sonuc hazir

   bit_manipulasyon_birimi #(.XLEN(32)) bman (
      .clk_i(clk_i), .rst_i(~rst_i),          // birim rst AKTIF-YUKSEK
      .din_valid_i(b_baslat), .din_ready_o(b_din_rdy), .din_decoded_o(),
      .din_value1_i(yurut_deger1_i), .din_value2_i(yurut_deger2_i), .din_value3_i(32'b0),
      .din_instruction_i(yurut_buyruk_i),
      .dout_valid_o(b_dout_valid), .dout_ready_i(mc_b_aktif_r), .dout_result_o(b_result)
   );

   always @(posedge clk_i) begin
      if (!rst_i) begin
         mc_b_aktif_r <= 1'b0;
      end
      else if (b_kabul) begin
         mc_b_aktif_r  <= 1'b1;
         mc_b_rd_r     <= yurut_rd_adres_i;
         mc_b_etiket_r <= yurut_etiket_i;
         mc_b_yaz_r    <= (yazmac == `YAZMAC_YAZ) && (yurut_rd_adres_i != 5'd0);
      end
      else if (b_tamam) begin
         mc_b_aktif_r <= 1'b0;
      end
   end

   // Mesgul: DIV veya B cok-cevrimli birim calisirken -> ust modul dondurur.
   wire div_mesgul = mc_baslat || (mc_aktif_r && !div_bitti);
   wire b_mesgul   = (bmanip_mi || mc_b_aktif_r) && !b_tamam;
   assign mesgul_o = div_mesgul || b_mesgul;

   // Cok-cevrim tamamlanmasi (DIV veya B; ikisi ayni anda olamaz)
   wire        mc_tamam  = div_tamam || b_tamam;
   wire [4:0]  mc_rd     = div_tamam ? mc_rd_r     : mc_b_rd_r;
   wire [31:0] mc_veri   = div_tamam ? div_sonuc   : b_result;
   wire [3:0]  mc_etiket = div_tamam ? mc_etiket_r : mc_b_etiket_r;
   wire        mc_yaz    = div_tamam ? mc_yaz_r    : mc_b_yaz_r;

   // ---------------- Karsilastirmalar (dallanma icin) ----------------
   // Kosullu dallanmada operandlar rs1, rs2'dir (OPERAND_REG).
   wire alu_esittir   = (yurut_deger1_i == yurut_deger2_i);
   wire alu_kucuktur  = ($signed(yurut_deger1_i) < $signed(yurut_deger2_i));
   wire alu_kucuktur_u= (yurut_deger1_i < yurut_deger2_i);

   // ---------------- Dallanma cozumleme ----------------
   wire [31:0] dal_g1_ps;
   wire        dal_g1_ps_gecerli;
   wire [31:0] dal_g2_ps, dal_g2_hedef;
   wire        dal_g2_guncelle, dal_g2_atladi, dal_g2_hatali;
   wire [31:0] dal_atlamadi;

   // Hedef tabani: JALR -> rs1 (deger1); diger (branch/JAL) -> PS
   wire [31:0] dal_islec = (dal_kod == `DAL_JALR) ? yurut_deger1_i : yurut_ps_i;

   dallanma_birimi dal (
      .islem_kod_i               ( dal_kod          ),
      .islem_ps_i                ( yurut_ps_i       ),
      .islem_islec_i             ( dal_islec        ),
      .islem_anlik_i             ( yurut_imm_i      ),
      .islem_atladi_i            ( yurut_atladi_i   ),
      .islem_rvc_i               ( yurut_rvc_i      ),
      .alu_esittir_i             ( alu_esittir      ),
      .alu_kucuktur_i            ( alu_kucuktur     ),
      .alu_kucuktur_isaretsiz_i  ( alu_kucuktur_u   ),
      .g1_ps_o                   ( dal_g1_ps        ),
      .g1_ps_gecerli_o           ( dal_g1_ps_gecerli),
      .g2_ps_o                   ( dal_g2_ps        ),
      .g2_hedef_ps_o             ( dal_g2_hedef     ),
      .g2_guncelle_o             ( dal_g2_guncelle  ),
      .g2_atladi_o               ( dal_g2_atladi    ),
      .g2_hatali_tahmin_o        ( dal_g2_hatali    ),
      .ps_atlamadi_o             ( dal_atlamadi     )
   );

   wire dallanma_mi = yurut_gecerli_i && (birim == `BIRIM_DALLANMA);

   // ---------------- CSR / Trap birimi ----------------
   wire        csr_mi = yurut_gecerli_i && (birim == `BIRIM_CSR);
   wire [31:0] csr_oku;
   wire        csr_trap;
   wire        csr_tuzak;       // tuzak girisi -> mevcut buyrugu squash (commit/mem yok)
   wire [31:0] csr_trap_hedef;

   // FCSR: csr_birimi <-> fpu_temiz baglantilari
   wire [2:0] csr_frm;        // FCSR.frm -> FPU (DYN yuvarlama)
   wire [4:0] fpu_bayrak;     // FPU istisna bayraklari -> CSR biriktirme
   // FP islemi bu cevrim emekli oldu mu (tuzak/bekleme yokken) -> bayrak biriktir
   wire fp_bayrak_yaz = fpu_mi && !csr_tuzak && !mem_bekle_o;

   csr_birimi #(.RESET_MTVEC(32'h8000_0000)) csr (
      .clk_i        ( clk_i ),
      .rst_i        ( rst_i ),
      .gecerli_i    ( yurut_gecerli_i ),
      .csr_mi_i     ( csr_mi ),
      .funct3_i     ( yurut_buyruk_i[14:12] ),
      .csr_adres_i  ( yurut_buyruk_i[31:20] ),
      .rs1_deger_i  ( yurut_deger1_i ),
      .zimm_i       ( yurut_buyruk_i[19:15] ),
      .sys_i        ( yurut_mikroislem_i[`SYS] ),
      .pc_i         ( yurut_ps_i ),
      .dis_kesme_i  ( dis_kesme_i ),
      .zaman_kesme_i( zaman_kesme_i ),
      .yazilim_kesme_i( yazilim_kesme_i ),
      .fp_bayrak_i  ( fpu_bayrak ),
      .fp_bayrak_yaz_i( fp_bayrak_yaz ),
      .frm_o        ( csr_frm ),
      .csr_oku_o    ( csr_oku ),
      .trap_o       ( csr_trap ),
      .tuzak_o      ( csr_tuzak ),
      .trap_hedef_o ( csr_trap_hedef )
   );

   // ---------------- Bellek islem birimi (LSU) ----------------
   wire [3:0]  bib_kod = yurut_mikroislem_i[`BIB];
   wire [31:0] lsu_adres = alu_sonuc;          // adres = rs1 + imm
   wire        lsu_oku, lsu_yaz;
   wire [3:0]  lsu_maske;
   wire [31:0] lsu_veri;
   wire        bib_mi = yurut_gecerli_i && (birim == `BIRIM_BIB);

   // FLW/FSW: bellek arayuzu LSU ile ayni; veri f-RF'ye/f-RF'den.
   wire is_flw = yurut_gecerli_i && (yurut_buyruk_i[6:2] == `OPCODE_FPU_LW);
   wire is_fsw = yurut_gecerli_i && (yurut_buyruk_i[6:2] == `OPCODE_FPU_SW);
   wire [31:0] lsu_sakla_veri = is_fsw ? yurut_fdeger2_i : yurut_rs2_deger_i;

   bellek_islem_birimi lsu (
      .clk_i(clk_i), .rst_i(rst_i),
      .buyruk_secim_i(bib_kod),
      .rd_i(lsu_adres),               // adres (byte ofseti rd_i[1:0])
      .rs2_i(lsu_sakla_veri),         // store verisi (FSW ise f[rs2])
      .veri_o(lsu_veri), .maske_o(lsu_maske),
      .oku_o(lsu_oku), .yaz_o(lsu_yaz)
   );

   // ---------------- Kayan nokta birimi (RV32F) ----------------
   wire        fpu_mi = yurut_gecerli_i && (birim == `BIRIM_FPU);
   wire [31:0] fpu_sonuc;
   wire        fpu_int;     // sonuc tamsayi RF'ye mi
   // FMADD ailesi: opcode[6:2]=100xx (yurut_buyruk_i[6:2]); op = opcode[3:2]={neg_prod,sub_c}
   wire        fma_mi = (yurut_buyruk_i[6:4] == 3'b100) && (yurut_buyruk_i[1:0] == 2'b11);
   fpu_temiz fpu (
      .funct7_i(yurut_buyruk_i[31:25]),
      .rm_i(yurut_buyruk_i[14:12]),
      .frm_i(csr_frm),              // DYN(111) yuvarlama icin FCSR.frm
      .rs2f_i(yurut_buyruk_i[24:20]),
      .f1_i(yurut_fdeger1_i),
      .f2_i(yurut_fdeger2_i),
      .f3_i(yurut_fdeger3_i),
      .x1_i(yurut_deger1_i),        // FCVT.S.W / FMV.W.X icin int rs1
      .fma_gecerli_i(fma_mi),
      .fma_op_i(yurut_buyruk_i[3:2]),  // {neg_prod, sub_c}
      .sonuc_o(fpu_sonuc),
      .tamsayi_sonuc_o(fpu_int),
      .bayrak_o(fpu_bayrak)
   );

   // ---------------- Atomik birim (RV32A) ----------------
   wire        atomik_mi = yurut_gecerli_i && (birim == `BIRIM_ATOMIC);
   wire [31:0] atom_rd, atom_mem_yeni;
   wire        atom_oku, atom_yaz;

   atomik_birim atom (
      .clk_i(clk_i), .rst_i(rst_i),
      .gecerli_i(atomik_mi && !csr_tuzak),
      .kod_i(yurut_buyruk_i[31:27]),  // funct5
      .adres_i(yurut_deger1_i),       // rs1
      .rs2_i(yurut_deger2_i),         // rs2
      .mem_eski_i(mem_veri_i),        // mem[rs1] (kombinasyonel)
      .rd_veri_o(atom_rd),
      .mem_yeni_o(atom_mem_yeni),
      .mem_oku_o(atom_oku),
      .mem_yaz_o(atom_yaz),
      .sc_basari_o()
   );

   // Bellek adresi: atomik -> rs1 (offset yok); diger -> rs1+imm (ALU)
   wire [31:0] mem_adres = atomik_mi ? yurut_deger1_i : lsu_adres;

   assign mem_adres_o = mem_adres;
   assign mem_oku_o   = (bib_mi && lsu_oku) || (atomik_mi && atom_oku);
   assign mem_yaz_o   = ((bib_mi && lsu_yaz) || (atomik_mi && atom_yaz)) && !csr_tuzak;

   // Bellek erisimi devam ediyor ama slave hazir degil -> buyrugu execute'te dondur.
   wire mem_erisim = bib_mi || atomik_mi;
   assign mem_bekle_o = mem_erisim && !mem_hazir_i && !csr_tuzak;
   assign mem_veri_o  = atomik_mi ? atom_mem_yeni : lsu_veri;
   assign mem_maske_o = atomik_mi ? 4'b1111       : lsu_maske;

   // Yuklenen veriyi byte ofsetine gore hizala + isaret/sifir genislet
   wire [4:0]  yukle_kaydir = {mem_adres[1:0], 3'b0};   // ofset*8
   wire [31:0] yukle_hizali = mem_veri_i >> yukle_kaydir;
   reg  [31:0] yukle_veri;
   always @* begin
      case (bib_kod)
         `BIB_LW:  yukle_veri = mem_veri_i;
         `BIB_LH:  yukle_veri = {{16{yukle_hizali[15]}}, yukle_hizali[15:0]};
         `BIB_LHU: yukle_veri = {16'b0, yukle_hizali[15:0]};
         `BIB_LB:  yukle_veri = {{24{yukle_hizali[7]}}, yukle_hizali[7:0]};
         `BIB_LBU: yukle_veri = {24'b0, yukle_hizali[7:0]};
         default:  yukle_veri = mem_veri_i;
      endcase
   end

   // ---------------- Geri yazma verisi secimi ----------------
   reg [31:0] wb_veri;
   always @* begin
      if (bib_mi && lsu_oku)
         wb_veri = yukle_veri;                  // LOAD verisi
      else if (atomik_mi)
         wb_veri = atom_rd;                     // atomik: eski deger / SC sonucu
      else if (csr_mi)
         wb_veri = csr_oku;                     // CSR eski degeri
      else if (fpu_mi && fpu_int)
         wb_veri = fpu_sonuc;                   // FPU tamsayi sonucu (FEQ/FCVT.W/FMV.X)
      else case (geriyaz)
         `GERIYAZ_KAYNAK_YURUT: wb_veri = alu_sonuc;
         `GERIYAZ_KAYNAK_PC:    wb_veri = dal_atlamadi;   // baglanti = PS + 4 (RVC degilse)
         `GERIYAZ_KAYNAK_CARP:  wb_veri = carp_sonuc;     // RV32M carpma sonucu
         default:               wb_veri = alu_sonuc;
      endcase
   end

   // Tek-cevrimli buyruklar ayni cevrimde yazar (cok-cevrimli BOLME ve B HARIC:
   //  onlar baslatma cevriminde rd yazmaz, sonucu tamamlaninca geri yazilir).
   wire normal_yaz = yurut_gecerli_i && (yazmac == `YAZMAC_YAZ)
                     && (yurut_rd_adres_i != 5'd0)
                     && (birim != `BIRIM_BOLME) && !bmanip_mi;

   assign wb_yaz_adres_o   = mc_tamam ? mc_rd     : yurut_rd_adres_i;
   assign wb_yaz_veri_o    = mc_tamam ? mc_veri   : wb_veri;
   assign wb_yaz_etiket_o  = mc_tamam ? mc_etiket : yurut_etiket_i;
   assign wb_yaz_gecerli_o = (mc_tamam ? mc_yaz : normal_yaz) && !csr_tuzak && !mem_bekle_o;

   // ---------------- Kayan nokta (F) geri yazma ----------------
   //  FLW: yuklenen kelime -> f[rd];  FPU f-sonucu (FADD/.../FMV.W.X) -> f[rd].
   wire fpu_f_yaz = fpu_mi && !fpu_int;
   assign fwb_yaz_adres_o   = yurut_rd_adres_i;
   assign fwb_yaz_etiket_o  = yurut_etiket_i;
   assign fwb_yaz_veri_o    = is_flw ? mem_veri_i : fpu_sonuc;
   assign fwb_yaz_gecerli_o = (is_flw || fpu_f_yaz) && !csr_tuzak && !mem_bekle_o;

   // ---------------- Ongorucu egitimi ----------------
   assign egit_ps_o            = dal_g2_ps;
   assign egit_hedef_ps_o      = dal_g2_hedef;
   assign egit_guncelle_o      = dallanma_mi && dal_g2_guncelle;
   assign egit_atladi_o        = dal_g2_atladi;
   assign egit_hatali_tahmin_o = dallanma_mi && dal_g2_hatali;

   // ---------------- Yonlendirme: trap/mret (oncelik) veya yanlis tahmin ----------------
   assign yonlendir_gecerli_o = csr_trap || (dallanma_mi && dal_g1_ps_gecerli);
   assign yonlendir_ps_o      = csr_trap ? csr_trap_hedef : dal_g1_ps;

   // Yonlendirme -> ardisik duzeni bosalt (coz + getir).
   assign bosalt_o = yonlendir_gecerli_o;

endmodule

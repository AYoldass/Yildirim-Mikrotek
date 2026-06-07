`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  cekirdek  -  RISC-V cekirdek ust modulu (Faz 3 ara entegrasyon)
// ---------------------------------------------------------------------------
//  Ardisik duzen:  GETIR -> COZ -> YURUT(=geri yazma)
//     F: getir_altsistem (PS uretimi, L1B erisimi, dallanma ongorusu)
//     D: coz_asamasi     (cozme + yazmac okuma)  + yazmac_obegi (scoreboard RF)
//     E: yurut_asamasi   (ALU + dallanma cozumleme + geri yazma)
//
//  Tehlike (hazard) kilidi: scoreboard tabanli. coz okudugu kaynak gecerli
//  degilse (uretici hala ardisik duzende) coz duraklatilir (durdur) ve getir
//  dondurulur (cek_duraklat); asagiya kabarcik gonderilir. Uretici geri yazinca
//  (etiket eslesmesi ile) kaynak gecerli olur ve tuketici yayinlanir.
//
//  Bu fazda BELLEK asamasi ve cok-cevrimli birimler (MUL/DIV/FPU) yoktur;
//  yurut ayni cevrimde geri yazar. Kapsam: RV32I ALU/LUI/AUIPC/dallanma/JAL(R).
//
//  rst_i AKTIF-DUSUK.
// ===========================================================================

module cekirdek (
   input                    clk_i,
   input                    rst_i,

   // --- Kesme kaynaklari (cevresel birimlerden; baglanmazsa kesme olmaz) ---
   input                    dis_kesme_i,
   input                    zaman_kesme_i,
   input                    yazilim_kesme_i,

   // --- Buyruk bellegi arayuzu (kombinasyonel okuma) ---
   output  [31:0]           bel_adres_o,
   input   [31:0]           bel_buyruk_i,

   // --- Veri bellegi arayuzu (kombinasyonel okuma, senkron yazma) ---
   output  [31:0]           veri_adres_o,
   output                   veri_oku_o,
   output                   veri_yaz_o,
   output  [31:0]           veri_yaz_veri_o,
   output  [3:0]            veri_maske_o,
   input   [31:0]           veri_oku_veri_i,
   input                    veri_hazir_i        // 0: veri bellegi mesgul -> dondur
);

   // ---------------- Getir -> Coz ----------------
   wire [31:0] g_buyruk, g_ps;
   wire        g_gecerli, g_atladi, g_rvc;

   // ---------------- Coz <-> RF ----------------
   wire [4:0]  oku_adres1, oku_adres2;
   wire [31:0] rs1_deger, rs2_deger;
   wire        rs1_gecerli, rs2_gecerli;
   wire [3:0]  rs1_etiket, rs2_etiket;   // (su an kullanilmiyor)

   wire        rs1_kullanilir, rs2_kullanilir;
   wire [4:0]  rezerve_adres;
   wire [3:0]  rezerve_etiket;
   wire        rezerve_gecerli;

   // ---------------- Coz <-> F RF (kayan nokta) ----------------
   wire [4:0]  f_oku1, f_oku2, f_oku3;
   wire [31:0] frs1_deger, frs2_deger, frs3_deger;
   wire        frs1_gecerli, frs2_gecerli, frs3_gecerli;
   wire        f_rs1_kullanilir, f_rs2_kullanilir, f_rs3_kullanilir;
   wire [4:0]  f_rezerve_adres;
   wire [3:0]  f_rezerve_etiket;
   wire        f_rezerve_gecerli;
   // Yurut -> F RF geri yazma
   wire [4:0]  fwb_adres;
   wire [31:0] fwb_veri;
   wire [3:0]  fwb_etiket;
   wire        fwb_gecerli;

   // ---------------- Coz -> Yurut ----------------
   wire [31:0] y_ps, y_d1, y_d2, y_rs2, y_imm, y_buyruk, y_fd1, y_fd2, y_fd3;
   wire [`MI_BIT-1:0] y_mi;
   wire [4:0]  y_rd, y_rs1a, y_rs2a;
   wire [3:0]  y_etiket;
   wire        y_gecerli, y_atladi, y_rvc;

   // ---------------- Yurut -> RF / Getir ----------------
   wire [4:0]  wb_adres;
   wire [31:0] wb_veri;
   wire [3:0]  wb_etiket;
   wire        wb_gecerli;

   wire [31:0] egit_ps, egit_hedef;
   wire        egit_guncelle, egit_atladi, egit_hatali;
   wire [31:0] yonlendir_ps;
   wire        yonlendir_gecerli;
   wire        bosalt;
   wire        mesgul;          // yurut cok-cevrimli birim (BOLME/B) mesgul
   wire        mem_bekle;       // yurut bellek beklemesi (yurut'taki buyrugu dondur)

   // ---------------- Tehlike (hazard) kilidi ----------------
   //  - scoreboard: kaynak gecerli degilse duraklat (RAW)
   //  - mesgul: yurut'ta cok-cevrimli birim (bolme) calisiyor -> getir+coz dondur
   wire hazard = g_gecerli &&
                 ( (rs1_kullanilir   && !rs1_gecerli)  ||
                   (rs2_kullanilir   && !rs2_gecerli)  ||
                   (f_rs1_kullanilir && !frs1_gecerli) ||
                   (f_rs2_kullanilir && !frs2_gecerli) ||
                   (f_rs3_kullanilir && !frs3_gecerli) );
   wire durdur = hazard || mesgul;

   // =========================================================== //
   //  GETIR (basit, kombinasyonel buyruk bellegi)
   // =========================================================== //
   getir_basit u_getir (
      .clk_i(clk_i), .rst_i(rst_i),
      .bel_adres_o(bel_adres_o), .bel_buyruk_i(bel_buyruk_i),
      .coz_buyruk_o(g_buyruk), .coz_buyruk_ps_o(g_ps),
      .coz_buyruk_gecerli_o(g_gecerli), .coz_buyruk_atladi_o(g_atladi),
      .coz_buyruk_rvc_o(g_rvc),
      // ongorucu egitimi (yurut)
      .egit_ps_i(egit_ps), .egit_hedef_ps_i(egit_hedef),
      .egit_guncelle_i(egit_guncelle), .egit_atladi_i(egit_atladi),
      .egit_hatali_tahmin_i(egit_hatali),
      // yanlis tahmin yonlendirmesi
      .yonlendir_gecerli_i(yonlendir_gecerli), .yonlendir_ps_i(yonlendir_ps),
      // kontrol (bellek beklemesinde de getir dondurulur)
      .duraklat_i(durdur || mem_bekle), .bosalt_i(bosalt)
   );

   // =========================================================== //
   //  YAZMAC OBEGI (scoreboard RF)
   // =========================================================== //
   yazmac_obegi u_rf (
      .clk_i(clk_i), .rst_i(rst_i),
      .oku_adres1_i(oku_adres1), .oku_adres2_i(oku_adres2),
      .oku_veri1_o(rs1_deger), .oku_veri1_gecerli_o(rs1_gecerli), .oku_veri1_etiket_o(rs1_etiket),
      .oku_veri2_o(rs2_deger), .oku_veri2_gecerli_o(rs2_gecerli), .oku_veri2_etiket_o(rs2_etiket),
      // geri yazma (yurut)
      .yaz_veri_i(wb_veri), .yaz_adres_i(wb_adres),
      .yaz_etiket_i(wb_etiket), .yaz_gecerli_i(wb_gecerli),
      // rezervasyon (coz yayinlarken)
      .etiket_i(rezerve_etiket), .etiket_adres_i(rezerve_adres),
      .etiket_gecerli_i(rezerve_gecerli)
   );

   // =========================================================== //
   //  KAYAN NOKTA YAZMAC OBEGI (f0-f31, scoreboard)
   // =========================================================== //
   fp_yazmac_obegi u_frf (
      .clk_i(clk_i), .rst_i(rst_i),
      .oku_adres1_i(f_oku1), .oku_adres2_i(f_oku2), .oku_adres3_i(f_oku3),
      .oku_veri1_o(frs1_deger), .oku_veri1_gecerli_o(frs1_gecerli),
      .oku_veri2_o(frs2_deger), .oku_veri2_gecerli_o(frs2_gecerli),
      .oku_veri3_o(frs3_deger), .oku_veri3_gecerli_o(frs3_gecerli),
      .yaz_veri_i(fwb_veri), .yaz_adres_i(fwb_adres),
      .yaz_etiket_i(fwb_etiket), .yaz_gecerli_i(fwb_gecerli),
      .etiket_i(f_rezerve_etiket), .etiket_adres_i(f_rezerve_adres),
      .etiket_gecerli_i(f_rezerve_gecerli)
   );

   // =========================================================== //
   //  COZ
   // =========================================================== //
   coz_asamasi u_coz (
      .clk_i(clk_i), .rst_i(rst_i),
      .coz_buyruk_i(g_buyruk), .coz_buyruk_ps_i(g_ps),
      .coz_buyruk_gecerli_i(g_gecerli), .coz_buyruk_atladi_i(g_atladi),
      .coz_buyruk_rvc_i(g_rvc),
      .oku_adres1_o(oku_adres1), .oku_adres2_o(oku_adres2),
      .rs1_deger_i(rs1_deger), .rs2_deger_i(rs2_deger),
      .f_oku1_o(f_oku1), .f_oku2_o(f_oku2), .f_oku3_o(f_oku3),
      .frs1_deger_i(frs1_deger), .frs2_deger_i(frs2_deger), .frs3_deger_i(frs3_deger),
      .rs1_kullanilir_o(rs1_kullanilir), .rs2_kullanilir_o(rs2_kullanilir),
      .f_rs1_kullanilir_o(f_rs1_kullanilir), .f_rs2_kullanilir_o(f_rs2_kullanilir),
      .f_rs3_kullanilir_o(f_rs3_kullanilir),
      .rezerve_adres_o(rezerve_adres), .rezerve_etiket_o(rezerve_etiket),
      .rezerve_gecerli_o(rezerve_gecerli),
      .f_rezerve_adres_o(f_rezerve_adres), .f_rezerve_etiket_o(f_rezerve_etiket),
      .f_rezerve_gecerli_o(f_rezerve_gecerli),
      .durdur_i(durdur), .dondur_i(mem_bekle), .bosalt_i(bosalt),
      .yurut_ps_o(y_ps), .yurut_deger1_o(y_d1), .yurut_deger2_o(y_d2),
      .yurut_rs2_deger_o(y_rs2), .yurut_imm_o(y_imm), .yurut_mikroislem_o(y_mi),
      .yurut_rd_adres_o(y_rd), .yurut_rs1_adres_o(y_rs1a), .yurut_rs2_adres_o(y_rs2a),
      .yurut_etiket_o(y_etiket), .yurut_buyruk_o(y_buyruk),
      .yurut_fdeger1_o(y_fd1), .yurut_fdeger2_o(y_fd2), .yurut_fdeger3_o(y_fd3),
      .yurut_gecerli_o(y_gecerli), .yurut_atladi_o(y_atladi),
      .yurut_rvc_o(y_rvc)
   );

   // =========================================================== //
   //  YURUT (= geri yazma)
   // =========================================================== //
   yurut_asamasi u_yurut (
      .clk_i(clk_i), .rst_i(rst_i),
      .yurut_ps_i(y_ps), .yurut_deger1_i(y_d1), .yurut_deger2_i(y_d2),
      .yurut_rs2_deger_i(y_rs2), .yurut_imm_i(y_imm), .yurut_mikroislem_i(y_mi),
      .yurut_buyruk_i(y_buyruk),
      .yurut_fdeger1_i(y_fd1), .yurut_fdeger2_i(y_fd2), .yurut_fdeger3_i(y_fd3),
      .yurut_rd_adres_i(y_rd), .yurut_etiket_i(y_etiket),
      .yurut_gecerli_i(y_gecerli), .yurut_atladi_i(y_atladi),
      .yurut_rvc_i(y_rvc),
      .dis_kesme_i(dis_kesme_i), .zaman_kesme_i(zaman_kesme_i), .yazilim_kesme_i(yazilim_kesme_i),
      .wb_yaz_adres_o(wb_adres), .wb_yaz_veri_o(wb_veri),
      .wb_yaz_etiket_o(wb_etiket), .wb_yaz_gecerli_o(wb_gecerli),
      .fwb_yaz_adres_o(fwb_adres), .fwb_yaz_veri_o(fwb_veri),
      .fwb_yaz_etiket_o(fwb_etiket), .fwb_yaz_gecerli_o(fwb_gecerli),
      .mesgul_o(mesgul),
      .mem_adres_o(veri_adres_o), .mem_oku_o(veri_oku_o), .mem_yaz_o(veri_yaz_o),
      .mem_veri_o(veri_yaz_veri_o), .mem_maske_o(veri_maske_o), .mem_veri_i(veri_oku_veri_i),
      .mem_hazir_i(veri_hazir_i), .mem_bekle_o(mem_bekle),
      .egit_ps_o(egit_ps), .egit_hedef_ps_o(egit_hedef),
      .egit_guncelle_o(egit_guncelle), .egit_atladi_o(egit_atladi),
      .egit_hatali_tahmin_o(egit_hatali),
      .yonlendir_ps_o(yonlendir_ps), .yonlendir_gecerli_o(yonlendir_gecerli),
      .bosalt_o(bosalt)
   );

endmodule

`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  getir_altsistem  -  Buyruk Getirme + Dallanma Ongorucu Alt Sistemi
// ---------------------------------------------------------------------------
//  Bu modul, ayri ayri tasarlanmis getir_asama1 ve getir_asama2 (icinde
//  dallanma_ongorucu barindirir) birimlerini tutarli valid/ready (gecerli/
//  hazir) el-sikismasi ile birbirine baglayan ilk entegrasyon katmanidir.
//
//  Veri akisi:
//
//     +-----------+  g2_ps   +-----------+  coz_buyruk   ->  (Coz asamasina)
//     |  GETIR-1  |--------->|  GETIR-2  |--------------->
//     |  (PC/PS)  |<---------|  (+ Ongoru)|
//     +-----------+ g1_hazir +-----------+
//          |  ^                   |  ^
//   l1b_istek  | cek (redirect)   |  l1b_buyruk
//          v  |                   v  |
//      [ Buyruk Bellegi / L1 Buyruk Onbellegi ]
//
//  - getir_asama1 : Program sayacini (PS/PC) uretir, buyruk bellegine istek
//                   yapar, gelen PS'i getir_asama2'ye aktarir.
//  - getir_asama2 : Bellekten gelen buyrugu eslestirir, dallanma_ongorucu ile
//                   tahmin yapar, coz asamasina buyruk yollar. Tahmin "atladi"
//                   ise getir_asama1 hedef adrese yonlendirilir (cek_ps).
//
//  rst_i AKTIF-DUSUK'tur (alt birimlerin `if(!rst_i)` kullanimina uygun):
//     rst_i = 0 -> reset,  rst_i = 1 -> normal calisma.
// ===========================================================================

module getir_altsistem (
   input                       clk_i,
   input                       rst_i,            // aktif-dusuk reset

   // --- Buyruk bellegi (L1 Buyruk) istek arayuzu ---
   output  [31:0]              l1b_istek_adres_o,
   output                      l1b_istek_gecerli_o,
   input                       l1b_istek_hazir_i,

   // --- Buyruk bellegi (L1 Buyruk) cevap arayuzu ---
   input   [31:0]              l1b_buyruk_i,
   input                       l1b_buyruk_gecerli_i,
   output                      l1b_buyruk_hazir_o,

   // --- Coz (decode) asamasina giden buyruk akisi ---
   output  [31:0]              coz_buyruk_o,
   output  [31:0]              coz_buyruk_ps_o,
   output                      coz_buyruk_gecerli_o,
   output                      coz_buyruk_atladi_o,

   // --- Yurut (execute) geri beslemesi: ongorucu egitimi + yanlis tahmin ---
   input   [31:0]              yurut_ps_i,            // dallanma buyrugunun PS'i
   input   [31:0]              yurut_hedef_ps_i,      // gercek hedef adres
   input                       yurut_guncelle_i,      // ongorucuyu guncelle
   input                       yurut_atladi_i,        // gercekte atladi mi
   input                       yurut_hatali_tahmin_i, // tahmin yanlis miydi

   // --- Yurut yanlis tahmin yonlendirmesi (getir_asama1'i bosalt/yonlendir) ---
   input                       yurut_yonlendir_gecerli_i,
   input   [31:0]              yurut_yonlendir_ps_i,

   // --- Cekirdek kontrol (downstream backpressure / flush) ---
   input                       cek_duraklat_i,   // ardisik duzeni duraklat
   input                       cek_bosalt_i      // ardisik duzeni bosalt (flush)
);

   // -------------------- Asamalararasi sinyaller -------------------- //
   wire  [31:0]  g1_g2_ps_w;
   wire          g1_g2_ps_gecerli_w;
   wire          g1_g2_istek_yapildi_w;
   wire          g2_g1_ps_hazir_w;

   // getir_asama2 -> dallanma tahmini (getir_asama1'e yonlendirme) //
   wire  [31:0]  g2_dallanma_ps_w;
   wire          g2_dallanma_gecerli_w;

   // -------------------- getir_asama1'e giden yonlendirme (cek) -------------------- //
   // Oncelik: yurut yanlis-tahmin yonlendirmesi > ongorucu tahmini.
   wire  [31:0]  cek_ps_w        = yurut_yonlendir_gecerli_i ? yurut_yonlendir_ps_i
                                                             : g2_dallanma_ps_w;
   wire          cek_ps_gecerli_w = yurut_yonlendir_gecerli_i | g2_dallanma_gecerli_w;

   // =============================================================== //
   //  GETIR ASAMA 1                                                  //
   // =============================================================== //
   getir_asama1 u_getir1 (
      .clk_i                ( clk_i                 ),
      .rst_i                ( rst_i                 ),

      .l1b_istek_hazir_i    ( l1b_istek_hazir_i     ),
      .l1b_istek_adres_o    ( l1b_istek_adres_o     ),
      .l1b_istek_gecerli_o  ( l1b_istek_gecerli_o   ),

      .g2_istek_yapildi_o   ( g1_g2_istek_yapildi_w ),

      .g2_ps_o              ( g1_g2_ps_w            ),
      .g2_ps_hazir_i        ( g2_g1_ps_hazir_w      ),
      .g2_ps_gecerli_o      ( g1_g2_ps_gecerli_w    ),

      .cek_bosalt_i         ( cek_bosalt_i          ),
      .cek_duraklat_i       ( cek_duraklat_i        ),
      .cek_ps_i             ( cek_ps_w              ),
      .cek_ps_gecerli_i     ( cek_ps_gecerli_w      )
   );

   // =============================================================== //
   //  GETIR ASAMA 2  (dallanma_ongorucu icinde)                      //
   // =============================================================== //
   getir_asama2 u_getir2 (
      .clk_i                  ( clk_i                 ),
      .rst_i                  ( rst_i                 ),

      .g1_istek_yapildi_i     ( g1_g2_istek_yapildi_w ),

      .g1_ps_i                ( g1_g2_ps_w            ),
      .g1_ps_gecerli_i        ( g1_g2_ps_gecerli_w    ),
      .g1_ps_hazir_o          ( g2_g1_ps_hazir_w      ),

      .g1_dallanma_ps_o       ( g2_dallanma_ps_w      ),
      .g1_dallanma_gecerli_o  ( g2_dallanma_gecerli_w ),

      .yurut_ps_i             ( yurut_ps_i            ),
      .yurut_hedef_ps_i       ( yurut_hedef_ps_i      ),
      .yurut_guncelle_i       ( yurut_guncelle_i      ),
      .yurut_atladi_i         ( yurut_atladi_i        ),
      .yurut_hatali_tahmin_i  ( yurut_hatali_tahmin_i ),

      .l1b_buyruk_i           ( l1b_buyruk_i          ),
      .l1b_buyruk_gecerli_i   ( l1b_buyruk_gecerli_i  ),
      .l1b_buyruk_hazir_o     ( l1b_buyruk_hazir_o    ),

      .coz_buyruk_o           ( coz_buyruk_o          ),
      .coz_buyruk_ps_o        ( coz_buyruk_ps_o       ),
      .coz_buyruk_gecerli_o   ( coz_buyruk_gecerli_o  ),
      .coz_buyruk_atladi_o    ( coz_buyruk_atladi_o   ),

      .cek_bosalt_i           ( cek_bosalt_i          ),
      .cek_duraklat_i         ( cek_duraklat_i        )
   );

endmodule

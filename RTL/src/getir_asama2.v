`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  getir_asama2  (Getir Asama 2)  -  TEMIZ YENIDEN YAZIM
// ---------------------------------------------------------------------------
//  Gorev: getir_asama1'den gelen Program Sayaci (PS) akisi ile L1 Buyruk
//  onbelleginden gelen buyruk akisini eslestirip, dallanma ongorusu ile
//  birlikte coz (decode) asamasina sunmak.
//
//  Veri akisi ve hizalama:
//    - getir_asama1, L1B istegini kabul ettirdigi cevrimin ardindan ilgili
//      PS'i (g1_ps_i, g1_ps_gecerli_i) gecerli yapar.
//    - Ayni cevrimde L1B o adresin buyrugunu (l1b_buyruk_i, l1b_buyruk_gecerli_i)
//      gecerli olarak dondurur.
//    - Boylece (PS, buyruk) cifti g2'de ayni cevrimde hizalanir.
//
//  El-sikismasi (valid/ready):
//    - Asagi akis (coz) her cevrim tuketir; cek_duraklat_i ile duraklatilir.
//    - g1_ps_hazir_o / l1b_buyruk_hazir_o yalnizca cifti gercekten yakaladigimiz
//      cevrimde 1 olur. Bu sinyaller yalnizca KAYIT ve GIRIS sinyallerinden
//      turetilir; getir_asama1'in kombinasyonel ciktilarina bagli DEGILDIR.
//      (Onceki surumde modulun kendi cikis kablosunu @* icinde okumasi, iverilog
//       benzeri olay-guimli simulatorlerde yakinsamayan bir delta dongusune yol
//       aciyordu; bu surum bu desenden tamamen kacinir.)
//
//  Dallanma ongorusu:
//    - Ongorucu, coz cikisindaki buyrugun PS'i (coz_buyruk_ps_r) ile sorgulanir.
//    - "atlar" tahmini varsa: o buyruk coz_buyruk_atladi_o=1 ile teslim edilir,
//      gelen (yanlis-yol) sonraki cift KABUL EDILMEZ (kabarcik olusur) ve
//      getir_asama1 ongorulen hedefe (do_ongoru_w) yonlendirilir.
//
//  rst_i AKTIF-DUSUK'tur: 0 = reset, 1 = normal calisma.
// ===========================================================================

module getir_asama2(
   input                       clk_i,
   input                       rst_i,

   input                       g1_istek_yapildi_i,   // (uyumluluk; bu surumde kullanilmiyor)

   input   [31:0]              g1_ps_i,
   input                       g1_ps_gecerli_i,
   output                      g1_ps_hazir_o,

   output  [31:0]              g1_dallanma_ps_o,
   output                      g1_dallanma_gecerli_o,

   input   [31:0]              yurut_ps_i,
   input   [31:0]              yurut_hedef_ps_i,
   input                       yurut_guncelle_i,
   input                       yurut_atladi_i,
   input                       yurut_hatali_tahmin_i,

   input   [31:0]              l1b_buyruk_i,
   input                       l1b_buyruk_gecerli_i,
   output                      l1b_buyruk_hazir_o,

   output  [31:0]              coz_buyruk_o,
   output  [31:0]              coz_buyruk_ps_o,
   output                      coz_buyruk_gecerli_o,
   output                      coz_buyruk_atladi_o,

   input                       cek_bosalt_i,
   input                       cek_duraklat_i
);

   // ---------------- Cikis (coz) kayitlari ----------------
   reg [31:0] coz_buyruk_r,         coz_buyruk_ns;
   reg [31:0] coz_buyruk_ps_r,      coz_buyruk_ps_ns;
   reg        coz_buyruk_gecerli_r, coz_buyruk_gecerli_ns;

   // ---------------- Dallanma ongorucu ----------------
   wire        do_atladi_w;
   wire [31:0] do_ongoru_w;

   dallanma_ongorucu dal_ongorucu (
      .clk_i                 ( clk_i                ),
      .rst_i                 ( rst_i                ),
      .ps_i                  ( coz_buyruk_ps_r      ),
      .ps_gecerli_i          ( coz_buyruk_gecerli_r ),
      .atladi_o              ( do_atladi_w          ),
      .ongoru_o              ( do_ongoru_w          ),
      .yurut_ps_i            ( yurut_ps_i           ),
      .yurut_guncelle_i      ( yurut_guncelle_i     ),
      .yurut_atladi_i        ( yurut_atladi_i       ),
      .yurut_atlanan_adres_i ( yurut_hedef_ps_i     ),
      .yurut_hatali_tahmin_i ( yurut_hatali_tahmin_i)
   );

   // Coz cikisindaki gecerli buyruk dallanma olarak "atlar" tahmin edildi mi?
   wire atladi_w = do_atladi_w && coz_buyruk_gecerli_r;

   // Gelen (PS, buyruk) cifti yakalanabilir mi?
   //  - Her iki kaynak da gecerli olmali,
   //  - bosaltma (flush) olmamali,
   //  - coz cikisindaki buyruk "atlar" tahmin edilmemis olmali (yanlis-yol birak).
   wire kabul_w = g1_ps_gecerli_i && l1b_buyruk_gecerli_i && !atladi_w && !cek_bosalt_i;

   // ---------------- Sonraki-durum mantigi ----------------
   always @* begin
      coz_buyruk_ns         = coz_buyruk_r;
      coz_buyruk_ps_ns      = coz_buyruk_ps_r;
      coz_buyruk_gecerli_ns = coz_buyruk_gecerli_r;

      if (cek_bosalt_i) begin
         // Bosaltma: cikisi temizle (yanlis-yol).
         coz_buyruk_gecerli_ns = 1'b0;
      end
      else if (cek_duraklat_i) begin
         // Duraklatma: cikisi oldugu gibi tut.
      end
      else begin
         // Normal calisma: asagi akis bu cevrim tuketir.
         if (kabul_w) begin
            coz_buyruk_ns         = l1b_buyruk_i;
            coz_buyruk_ps_ns      = g1_ps_i;
            coz_buyruk_gecerli_ns = 1'b1;
         end
         else begin
            // Kabul edilemiyor (kaynak yok ya da yanlis-yol birakiliyor) -> kabarcik.
            coz_buyruk_gecerli_ns = 1'b0;
         end
      end
   end

   // ---------------- Kayitlar ----------------
   always @(posedge clk_i) begin
      if (!rst_i) begin
         coz_buyruk_r         <= 32'h0;
         coz_buyruk_ps_r      <= 32'h0;
         coz_buyruk_gecerli_r <= 1'b0;
      end
      else begin
         coz_buyruk_r         <= coz_buyruk_ns;
         coz_buyruk_ps_r      <= coz_buyruk_ps_ns;
         coz_buyruk_gecerli_r <= coz_buyruk_gecerli_ns;
      end
   end

   // ---------------- Cikislar ----------------
   // El-sikismasi: yalnizca cifti gercekten yakaladigimiz cevrimde hazir.
   //  (Yalnizca giris + kayit kaynaklarindan turer -> kombinasyonel donme yok.)
   assign g1_ps_hazir_o      = !cek_duraklat_i && kabul_w;
   assign l1b_buyruk_hazir_o = !cek_duraklat_i && kabul_w;

   assign coz_buyruk_o          = coz_buyruk_r;
   assign coz_buyruk_ps_o       = coz_buyruk_ps_r;
   assign coz_buyruk_gecerli_o  = coz_buyruk_gecerli_r;
   assign coz_buyruk_atladi_o   = atladi_w;

   // Ongorucu "atlar" dediyse getir_asama1'i hedefe yonlendir (tek atimlik).
   assign g1_dallanma_ps_o      = do_ongoru_w;
   assign g1_dallanma_gecerli_o = atladi_w && !cek_duraklat_i;

endmodule

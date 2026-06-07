`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  getir_basit  -  Basit, saglam Getir (Fetch) asamasi
// ---------------------------------------------------------------------------
//  Entegre cekirdek (cekirdek.v) icin kullanilir. Kombinasyonel (ayni cevrim)
//  buyruk bellegi okumasi varsayar (FPGA BRAM kombinasyonel okuma / sim modeli).
//  Boylece PC ve buyruk dogal olarak hizalidir; getir_altsistem'in ayrik
//  PC/buyruk boru hatlarinda olusan stall/flush hizalama sorunlari OLUSMAZ.
//
//  - PC (program sayaci) kaydi: pc_r.
//  - Buyruk = bel_buyruk_i = bellek[pc_r] (kombinasyonel).
//  - Dallanma ongorucu pc_r ile sorgulanir; "atlar" tahmininde siradaki PC
//    ongorulen hedeftir.
//  - duraklat_i: PC dondurulur (hazard kilidi).
//  - yonlendir_gecerli_i: yurut'tan yanlis tahmin -> PC hedefe atlar (en yuksek
//    oncelik; duraklatmayi da gecersiz kilar, zaten o buyruk bosaltilir).
//  - bosalt_i: yanlis-yol buyrugu coz tarafinda kabarciga cevrilir (coz.bosalt).
//
//  rst_i AKTIF-DUSUK.
// ===========================================================================

module getir_basit (
   input                    clk_i,
   input                    rst_i,

   // --- Buyruk bellegi (kombinasyonel okuma) ---
   output  [31:0]           bel_adres_o,
   input   [31:0]           bel_buyruk_i,

   // --- Coz asamasina ---
   output  [31:0]           coz_buyruk_o,
   output  [31:0]           coz_buyruk_ps_o,
   output                   coz_buyruk_gecerli_o,
   output                   coz_buyruk_atladi_o,
   output                   coz_buyruk_rvc_o,     // sikistirilmis (16-bit) miydi

   // --- Dallanma ongorucu egitimi (yurut'tan) ---
   input   [31:0]           egit_ps_i,
   input   [31:0]           egit_hedef_ps_i,
   input                    egit_guncelle_i,
   input                    egit_atladi_i,
   input                    egit_hatali_tahmin_i,

   // --- Yanlis tahmin yonlendirmesi (yurut'tan) ---
   input                    yonlendir_gecerli_i,
   input   [31:0]           yonlendir_ps_i,

   // --- Kontrol ---
   input                    duraklat_i,
   input                    bosalt_i
);

   reg [31:0] pc_r;
   reg        gecerli_r;

   // ---------------- Dallanma ongorucu ----------------
   wire        do_atladi_w;
   wire [31:0] do_ongoru_w;

   dallanma_ongorucu dal_ongorucu (
      .clk_i                 ( clk_i        ),
      .rst_i                 ( rst_i        ),
      .ps_i                  ( pc_r         ),
      .ps_gecerli_i          ( gecerli_r    ),
      .atladi_o              ( do_atladi_w  ),
      .ongoru_o              ( do_ongoru_w  ),
      .yurut_ps_i            ( egit_ps_i    ),
      .yurut_guncelle_i      ( egit_guncelle_i ),
      .yurut_atladi_i        ( egit_atladi_i ),
      .yurut_atlanan_adres_i ( egit_hedef_ps_i ),
      .yurut_hatali_tahmin_i ( egit_hatali_tahmin_i )
   );

   wire atladi_w = gecerli_r && do_atladi_w;

   // ---------------- Sikistirilmis (RVC) genisletme ----------------
   //  bel_buyruk_i, byte adresi pc_r'den baslayan 32 bittir. Dusuk yari-soz
   //  [1:0] != 11 ise 16-bit sikistirilmis buyruk -> 32-bit'e acilir, PC += 2.
   wire        rvc_w = (bel_buyruk_i[1:0] != 2'b11);
   wire [31:0] acilan_w;
   sikistirilmis_cozucu rvc_coz (
      .c_i      ( bel_buyruk_i[15:0] ),
      .buyruk_o ( acilan_w ),
      .gecersiz_o (  )
   );
   wire [31:0] buyruk_w   = rvc_w ? acilan_w : bel_buyruk_i;
   wire [31:0] buyruk_boy = rvc_w ? 32'd2    : 32'd4;

   // ---------------- Siradaki PC ----------------
   wire [31:0] siradaki_pc = yonlendir_gecerli_i ? yonlendir_ps_i :
                             duraklat_i           ? pc_r           :
                             atladi_w             ? do_ongoru_w    :
                                                    pc_r + buyruk_boy;

   always @(posedge clk_i) begin
      if (!rst_i) begin
         pc_r      <= 32'h8000_0000;
         gecerli_r <= 1'b1;
      end
      else begin
         pc_r      <= siradaki_pc;
         gecerli_r <= 1'b1;
      end
   end

   assign bel_adres_o          = pc_r;
   assign coz_buyruk_o         = buyruk_w;       // (RVC ise acilmis 32-bit)
   assign coz_buyruk_ps_o      = pc_r;
   assign coz_buyruk_rvc_o     = rvc_w;
   // Yanlis-yol buyrugu coz tarafinda bosalt_i ile kabarciga cevrilir; getir
   // her zaman pc_r'deki gercek buyrugu sunar.
   assign coz_buyruk_gecerli_o = gecerli_r && !yonlendir_gecerli_i;
   assign coz_buyruk_atladi_o  = atladi_w;

endmodule

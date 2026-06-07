`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  soc_l1  -  L1 veri onbellekli SoC (tam bellek hiyerarsisi)
// ---------------------------------------------------------------------------
//  Veri yolu:
//    cekirdek -> veri_yolu_kopru -> veri_yolu_birimi (bib<->port)
//             -> veri_onbellegi_denetleyici (port) -> { l1_sram, ana_bellek(vy) }
//  Buyruk getirme: ayri buyruk bellegi (kombinasyonel).
//
//  ONBELLEKLEME: veri_yolu_birimi, RAM_BASE_ADDR (0x4000_0000) bolgesini
//  onbelleklenebilir isaretler. Bu yuzden VERI adresleri 0x4000_xxxx olmali;
//  aksi bolgeler L1'de uncached yoldan dogrudan ana bellege gider.
//  rst_i AKTIF-DUSUK.
// ===========================================================================

module soc_l1 #(
   parameter integer IKELIME = 1024,        // buyruk bellegi kelime
   parameter integer DKELIME = 8192         // ana (veri) bellek kelime
)(
   input clk_i,
   input rst_i
);

   // ---------------- Cekirdek ----------------
   wire [31:0] iadr, ibuf;
   wire [31:0] dadr, dwdata, drdata;
   wire        doku, dyaz, dhazir;
   wire [3:0]  dmask;

   cekirdek u_cekirdek (
      .clk_i(clk_i), .rst_i(rst_i),
      .dis_kesme_i(1'b0), .zaman_kesme_i(1'b0), .yazilim_kesme_i(1'b0),
      .bel_adres_o(iadr), .bel_buyruk_i(ibuf),
      .veri_adres_o(dadr), .veri_oku_o(doku), .veri_yaz_o(dyaz),
      .veri_yaz_veri_o(dwdata), .veri_maske_o(dmask),
      .veri_oku_veri_i(drdata), .veri_hazir_i(dhazir)
   );

   // ---------------- Buyruk bellegi (kombinasyonel) ----------------
   reg [31:0] ibellek [0:IKELIME-1];
   localparam integer IAW = $clog2(IKELIME);
   assign ibuf = ibellek[iadr[IAW+1:2]];

   // ---------------- kopru <-> veri_yolu_birimi (bib) ----------------
   wire        bib_gecerli, bib_oku, bib_yaz;
   wire [31:0] bib_adres, bib_veri;
   wire [3:0]  bib_maske;
   wire        bellek_hazir, bellek_gecerli;
   wire [31:0] bellek_veri;

   veri_yolu_kopru u_kopru (
      .clk_i(clk_i), .rst_i(rst_i),
      .cek_adres_i(dadr), .cek_oku_i(doku), .cek_yaz_i(dyaz),
      .cek_veri_i(dwdata), .cek_maske_i(dmask),
      .cek_oku_veri_o(drdata), .cek_hazir_o(dhazir),
      .bib_istek_gecerli_o(bib_gecerli), .bib_istek_oku_o(bib_oku), .bib_istek_yaz_o(bib_yaz),
      .bib_istek_adres_o(bib_adres), .bib_veri_o(bib_veri), .bib_istek_maske_o(bib_maske),
      .bellek_hazir_i(bellek_hazir), .bellek_gecerli_i(bellek_gecerli), .bellek_veri_i(bellek_veri)
   );

   // ---------------- veri_yolu_birimi <-> L1 (port) ----------------
   wire [31:0] p_adres, p_veri_yaz;
   wire        p_gecerli, p_yaz, p_onbellek, p_hazir;
   wire [3:0]  p_maske;
   wire [31:0] p_veri_oku;
   wire        p_veri_gecerli, p_veri_hazir;

   veri_yolu_birimi u_vyb (
      .clk_i(clk_i), .rstn_i(rst_i),
      .port_istek_adres_o(p_adres), .port_istek_gecerli_o(p_gecerli),
      .port_istek_onbellekleme_o(p_onbellek),
      .port_istek_yaz_o(p_yaz), .port_istek_veri_o(p_veri_yaz),
      .port_istek_maske_o(p_maske), .port_istek_hazir_i(p_hazir),
      .port_veri_i(p_veri_oku), .port_veri_gecerli_i(p_veri_gecerli), .port_veri_hazir_o(p_veri_hazir),
      .bib_istek_gecerli_i(bib_gecerli), .bib_istek_yaz_i(bib_yaz),
      .bib_veri_i(bib_veri), .bib_istek_oku_i(bib_oku),
      .bib_istek_adres_i(bib_adres), .bib_istek_maske_i(bib_maske),
      .bellek_hazir_o(bellek_hazir), .bellek_veri_o(bellek_veri), .bellek_gecerli_o(bellek_gecerli)
   );

   // ---------------- L1 <-> SRAM + vy ----------------
   wire                                       l1_gecersiz;
   wire [`ADRES_SATIR_BIT-1:0]                l1_satir;
   wire [`L1V_YOL-1:0]                        l1_yaz;
   wire [(`ADRES_ETIKET_BIT*`L1V_YOL)-1:0]    l1_etiket_y, l1_etiket_o;
   wire [(`L1_BLOK_BIT*`L1V_YOL)-1:0]         l1_blok_y, l1_blok_o;
   wire                                       l1_veri_gecerli;

   wire [31:0]              vy_adres, vy_veri_yaz;
   wire                     vy_gecerli, vy_onbellek, vy_hazir, vy_yaz;
   wire [`L1_BLOK_BIT-1:0]  vy_veri_oku;
   wire                     vy_veri_gecerli, vy_veri_hazir;

   veri_onbellegi_denetleyici u_l1 (
      .clk_i(clk_i), .rst_i(rst_i),
      .port_istek_adres_i(p_adres), .port_istek_gecerli_i(p_gecerli),
      .port_istek_yaz_i(p_yaz), .port_istek_veri_i(p_veri_yaz),
      .port_istek_maske_i(p_maske), .port_istek_hazir_o(p_hazir),
      .port_istek_onbellekleme_i(p_onbellek),
      .port_veri_o(p_veri_oku), .port_veri_gecerli_o(p_veri_gecerli), .port_veri_hazir_i(p_veri_hazir),
      .l1_istek_gecersiz_o(l1_gecersiz), .l1_istek_satir_o(l1_satir), .l1_istek_yaz_o(l1_yaz),
      .l1_istek_etiket_o(l1_etiket_y), .l1_istek_blok_o(l1_blok_y),
      .l1_veri_etiket_i(l1_etiket_o), .l1_veri_blok_i(l1_blok_o), .l1_veri_gecerli_i(l1_veri_gecerli),
      .vy_istek_adres_o(vy_adres), .vy_istek_gecerli_o(vy_gecerli),
      .vy_istek_onbellekleme_o(vy_onbellek), .vy_istek_hazir_i(vy_hazir),
      .vy_istek_yaz_o(vy_yaz), .vy_istek_veri_o(vy_veri_yaz),
      .vy_veri_i(vy_veri_oku), .vy_veri_gecerli_i(vy_veri_gecerli), .vy_veri_hazir_o(vy_veri_hazir)
   );

   l1_sram u_l1sram (
      .clk_i(clk_i), .rst_i(rst_i),
      .gecersiz_i(l1_gecersiz), .satir_i(l1_satir), .yaz_i(l1_yaz),
      .etiket_i(l1_etiket_y), .blok_i(l1_blok_y),
      .etiket_o(l1_etiket_o), .blok_o(l1_blok_o), .gecerli_o(l1_veri_gecerli)
   );

   ana_bellek #(.KELIME(DKELIME)) u_ana (
      .clk_i(clk_i), .rst_i(rst_i),
      .vy_istek_adres_i(vy_adres), .vy_istek_gecerli_i(vy_gecerli), .vy_istek_yaz_i(vy_yaz),
      .vy_istek_veri_i(vy_veri_yaz), .vy_istek_hazir_o(vy_hazir),
      .vy_veri_o(vy_veri_oku), .vy_veri_gecerli_o(vy_veri_gecerli), .vy_veri_hazir_i(vy_veri_hazir)
   );

endmodule

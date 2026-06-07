`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  soc_veriyolu  -  Gercek veri_yolu_birimi ile SoC
// ---------------------------------------------------------------------------
//  cekirdek (veri arayuzu)  ->  veri_yolu_kopru  ->  veri_yolu_birimi  ->  port_bellek
//  Veri erisimleri depodaki GERCEK bus birimi (veri_yolu_birimi) uzerinden,
//  cok-cevrimli transaction protokolu ile yapilir; cekirdek bunu wait-state
//  (mem_bekle/dondur) ile dogru tolere eder. Buyruk getirme dogrudan (komb.).
//  rst_i AKTIF-DUSUK.
// ===========================================================================

module soc_veriyolu #(
   parameter integer KELIME = 8192
)(
   input  clk_i,
   input  rst_i
);

   // Cekirdek <-> dis
   wire [31:0] iadr, ibuf;
   wire [31:0] dadr, dwdata, drdata;
   wire        doku, dyaz, dhazir;
   wire [3:0]  dmask;

   // kopru <-> veri_yolu_birimi (bib)
   wire        bib_gecerli, bib_oku, bib_yaz;
   wire [31:0] bib_adres, bib_veri;
   wire [3:0]  bib_maske;
   wire        bellek_hazir, bellek_gecerli;
   wire [31:0] bellek_veri;

   // veri_yolu_birimi <-> port_bellek (port)
   wire [31:0] port_adres, port_veri_yaz;
   wire        port_gecerli, port_yaz, port_onbellek, port_hazir;
   wire [3:0]  port_maske;
   wire [31:0] port_veri_oku;
   wire        port_veri_gecerli, port_veri_hazir;

   cekirdek u_cekirdek (
      .clk_i(clk_i), .rst_i(rst_i),
      .dis_kesme_i(1'b0), .zaman_kesme_i(1'b0), .yazilim_kesme_i(1'b0),
      .bel_adres_o(iadr), .bel_buyruk_i(ibuf),
      .veri_adres_o(dadr), .veri_oku_o(doku), .veri_yaz_o(dyaz),
      .veri_yaz_veri_o(dwdata), .veri_maske_o(dmask),
      .veri_oku_veri_i(drdata), .veri_hazir_i(dhazir)
   );

   veri_yolu_kopru u_kopru (
      .clk_i(clk_i), .rst_i(rst_i),
      .cek_adres_i(dadr), .cek_oku_i(doku), .cek_yaz_i(dyaz),
      .cek_veri_i(dwdata), .cek_maske_i(dmask),
      .cek_oku_veri_o(drdata), .cek_hazir_o(dhazir),
      .bib_istek_gecerli_o(bib_gecerli), .bib_istek_oku_o(bib_oku), .bib_istek_yaz_o(bib_yaz),
      .bib_istek_adres_o(bib_adres), .bib_veri_o(bib_veri), .bib_istek_maske_o(bib_maske),
      .bellek_hazir_i(bellek_hazir), .bellek_gecerli_i(bellek_gecerli), .bellek_veri_i(bellek_veri)
   );

   veri_yolu_birimi u_vyb (
      .clk_i(clk_i), .rstn_i(rst_i),
      .port_istek_adres_o(port_adres), .port_istek_gecerli_o(port_gecerli),
      .port_istek_onbellekleme_o(port_onbellek),
      .port_istek_yaz_o(port_yaz), .port_istek_veri_o(port_veri_yaz),
      .port_istek_maske_o(port_maske), .port_istek_hazir_i(port_hazir),
      .port_veri_i(port_veri_oku), .port_veri_gecerli_i(port_veri_gecerli),
      .port_veri_hazir_o(port_veri_hazir),
      .bib_istek_gecerli_i(bib_gecerli), .bib_istek_yaz_i(bib_yaz),
      .bib_veri_i(bib_veri), .bib_istek_oku_i(bib_oku),
      .bib_istek_adres_i(bib_adres), .bib_istek_maske_i(bib_maske),
      .bellek_hazir_o(bellek_hazir), .bellek_veri_o(bellek_veri), .bellek_gecerli_o(bellek_gecerli)
   );

   port_bellek #(.KELIME(KELIME)) u_ram (
      .clk_i(clk_i), .rst_i(rst_i),
      .i_adres_i(iadr), .i_veri_o(ibuf),
      .port_istek_adres_i(port_adres), .port_istek_gecerli_i(port_gecerli),
      .port_istek_yaz_i(port_yaz), .port_istek_veri_i(port_veri_yaz),
      .port_istek_maske_i(port_maske), .port_istek_hazir_o(port_hazir),
      .port_veri_o(port_veri_oku), .port_veri_gecerli_o(port_veri_gecerli),
      .port_veri_hazir_i(port_veri_hazir)
   );

endmodule

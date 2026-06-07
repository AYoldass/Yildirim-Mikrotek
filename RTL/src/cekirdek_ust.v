`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  cekirdek_ust  -  SoC ust modulu (cekirdek + sistem_yolu)
// ---------------------------------------------------------------------------
//  RV32IMACFB cekirdegi, sistem veri yolu (sistem_yolu) uzerinden RAM ve
//  memory-mapped cevresel birimlere (UART, zamanlayici, tohost) baglanir.
//  RAM_GECIKME ile RAM'e bekleme-durumu (wait-state) verilebilir; cekirdek
//  bunu mem_bekle/dondur ile dogru sekilde tolere eder.
//  rst_i AKTIF-DUSUK.
// ===========================================================================

module cekirdek_ust #(
   parameter integer KELIME = 8192,
   parameter integer RAM_GECIKME = 0
)(
   input             clk_i,
   input             rst_i,

   output            uart_gecerli_o,
   output [7:0]      uart_veri_o,
   output            bitti_o,
   output [31:0]     cikis_kodu_o
);

   wire [31:0] iadr, ibuf;
   wire [31:0] dadr, dwdata, drdata;
   wire        doku, dyaz, dhazir;
   wire [3:0]  dmask;
   wire        zaman_kesme;

   cekirdek u_cekirdek (
      .clk_i(clk_i), .rst_i(rst_i),
      .dis_kesme_i(1'b0), .zaman_kesme_i(zaman_kesme), .yazilim_kesme_i(1'b0),
      .bel_adres_o(iadr), .bel_buyruk_i(ibuf),
      .veri_adres_o(dadr), .veri_oku_o(doku), .veri_yaz_o(dyaz),
      .veri_yaz_veri_o(dwdata), .veri_maske_o(dmask),
      .veri_oku_veri_i(drdata), .veri_hazir_i(dhazir)
   );

   sistem_yolu #(.KELIME(KELIME), .RAM_GECIKME(RAM_GECIKME)) u_yol (
      .clk_i(clk_i), .rst_i(rst_i),
      .i_adres_i(iadr), .i_veri_o(ibuf),
      .d_adres_i(dadr), .d_oku_i(doku), .d_yaz_i(dyaz),
      .d_veri_i(dwdata), .d_maske_i(dmask),
      .d_oku_veri_o(drdata), .d_hazir_o(dhazir),
      .zaman_kesme_o(zaman_kesme),
      .uart_gecerli_o(uart_gecerli_o), .uart_veri_o(uart_veri_o),
      .bitti_o(bitti_o), .cikis_kodu_o(cikis_kodu_o)
   );

endmodule

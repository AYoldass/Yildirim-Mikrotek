`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  port_bellek  -  veri_yolu_birimi PORT tarafi bellegi (+ buyruk okuma portu)
// ---------------------------------------------------------------------------
//  veri_yolu_birimi'nin "port" (l1/bellek) arayuzunu gerceklestiren basit RAM:
//    - Istegi her zaman kabul eder (port_istek_hazir_o = 1).
//    - Yazma: istek cevriminde RAM'e (maskeli) yazar.
//    - Okuma: istek cevriminden 1 cevrim sonra veriyi port_veri_gecerli ile sunar
//      (gercekci tek-cevrim okuma gecikmesi).
//  Ayrica cekirdek buyruk-getirme icin ikinci, kombinasyonel okuma portu.
//  rst_i AKTIF-DUSUK.
// ===========================================================================

module port_bellek #(
   parameter integer KELIME = 8192
)(
   input             clk_i,
   input             rst_i,

   // Buyruk getirme (kombinasyonel)
   input  [31:0]     i_adres_i,
   output [31:0]     i_veri_o,

   // PORT tarafi (veri_yolu_birimi'nden)
   input  [31:0]     port_istek_adres_i,
   input             port_istek_gecerli_i,
   input             port_istek_yaz_i,
   input  [31:0]     port_istek_veri_i,
   input  [3:0]      port_istek_maske_i,
   output            port_istek_hazir_o,
   output reg [31:0] port_veri_o,
   output reg        port_veri_gecerli_o,
   input             port_veri_hazir_i
);
   localparam integer AW = $clog2(KELIME);

   reg [31:0] ram [0:KELIME-1];
   wire [AW-1:0] i_idx = i_adres_i[AW+1:2];
   wire [AW-1:0] p_idx = port_istek_adres_i[AW+1:2];
   assign i_veri_o = ram[i_idx];

   assign port_istek_hazir_o = 1'b1;          // istegi her zaman kabul et

   reg [AW-1:0] oku_idx;
   reg          oku_bekliyor;
   integer b;
   always @(posedge clk_i) begin
      if (!rst_i) begin
         port_veri_gecerli_o <= 1'b0;
         oku_bekliyor        <= 1'b0;
      end else begin
         port_veri_gecerli_o <= 1'b0;
         // Yazma (istek cevriminde)
         if (port_istek_gecerli_i && port_istek_yaz_i)
            for (b=0;b<4;b=b+1) if (port_istek_maske_i[b])
               ram[p_idx][b*8 +: 8] <= port_istek_veri_i[b*8 +: 8];
         // Okuma: istek -> 1 cevrim sonra veri
         if (port_istek_gecerli_i && !port_istek_yaz_i) begin
            oku_idx      <= p_idx;
            oku_bekliyor <= 1'b1;
         end else if (oku_bekliyor) begin
            port_veri_o         <= ram[oku_idx];
            port_veri_gecerli_o <= 1'b1;
            oku_bekliyor        <= 1'b0;
         end
      end
   end

endmodule

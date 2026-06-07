`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  ana_bellek  -  L1 onbellegin "vy" (alt-seviye/ana bellek) tarafi
// ---------------------------------------------------------------------------
//  veri_onbellegi_denetleyici'nin vy arayuzune blok (=L1_BLOK_BIT=1 kelime)
//  duzeyinde hizmet eder: istegi her zaman kabul eder (vy_istek_hazir=1);
//  okumada 1 cevrim sonra veriyi vy_veri_gecerli ile sunar; yazmada o cevrim
//  bellege yazar. Adres kelime-hizali (blok=1 kelime).
//  rst_i AKTIF-DUSUK.
// ===========================================================================

module ana_bellek #(
   parameter integer KELIME = 8192
)(
   input             clk_i,
   input             rst_i,

   input  [31:0]                vy_istek_adres_i,
   input                        vy_istek_gecerli_i,
   input                        vy_istek_yaz_i,
   input  [`L1_BLOK_BIT-1:0]    vy_istek_veri_i,
   output                       vy_istek_hazir_o,
   output reg [`L1_BLOK_BIT-1:0] vy_veri_o,
   output reg                   vy_veri_gecerli_o,
   input                        vy_veri_hazir_i
);
   localparam integer AW = $clog2(KELIME);

   reg [`L1_BLOK_BIT-1:0] bellek [0:KELIME-1];
   wire [AW-1:0] idx = vy_istek_adres_i[AW+1:2];

   assign vy_istek_hazir_o = 1'b1;     // her zaman kabul

   reg [AW-1:0] oku_idx;
   reg          oku_bekliyor;
   always @(posedge clk_i) begin
      if (!rst_i) begin
         vy_veri_gecerli_o <= 1'b0;
         oku_bekliyor      <= 1'b0;
      end else begin
         vy_veri_gecerli_o <= 1'b0;
         if (vy_istek_gecerli_i && vy_istek_yaz_i) begin
            bellek[idx] <= vy_istek_veri_i;
         end
         if (vy_istek_gecerli_i && !vy_istek_yaz_i) begin
            oku_idx <= idx; oku_bekliyor <= 1'b1;
         end else if (oku_bekliyor) begin
            vy_veri_o <= bellek[oku_idx]; vy_veri_gecerli_o <= 1'b1; oku_bekliyor <= 1'b0;
         end
      end
   end

endmodule

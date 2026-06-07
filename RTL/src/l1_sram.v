`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  l1_sram  -  veri_onbellegi_denetleyici icin L1 etiket+blok SRAM'i (BRAM)
// ---------------------------------------------------------------------------
//  2-yollu (L1V_YOL), L1V_SATIR satirli; her giris: etiket (ADRES_ETIKET_BIT)
//  + blok (L1_BLOK_BIT). Senkron okuma (1 cevrim kayitli): satir_i'de sunulan
//  satirin verisi BIR cevrim sonra *_o'da gorunur (denetleyicinin bekledigi).
//  Yazma: l1_istek_yaz_i[yol] = 1 oldugunda ilgili yol o cevrim yazilir.
// ===========================================================================

module l1_sram (
   input                                          clk_i,
   input                                          rst_i,

   input                                          gecersiz_i,        // ~gecerli istek (kullanilmiyor)
   input  [`ADRES_SATIR_BIT-1:0]                  satir_i,
   input  [`L1V_YOL-1:0]                          yaz_i,
   input  [(`ADRES_ETIKET_BIT * `L1V_YOL)-1:0]    etiket_i,
   input  [(`L1_BLOK_BIT * `L1V_YOL)-1:0]         blok_i,

   output [(`ADRES_ETIKET_BIT * `L1V_YOL)-1:0]    etiket_o,
   output [(`L1_BLOK_BIT * `L1V_YOL)-1:0]         blok_o,
   output                                         gecerli_o
);

   reg [(`ADRES_ETIKET_BIT * `L1V_YOL)-1:0] etiket_mem [0:`L1V_SATIR-1];
   reg [(`L1_BLOK_BIT   * `L1V_YOL)-1:0]    blok_mem   [0:`L1V_SATIR-1];
   reg [`ADRES_SATIR_BIT-1:0] satir_r;

   integer y;
   always @(posedge clk_i) begin
      satir_r <= satir_i;
      for (y = 0; y < `L1V_YOL; y = y + 1) begin
         if (yaz_i[y]) begin
            etiket_mem[satir_i][y*`ADRES_ETIKET_BIT +: `ADRES_ETIKET_BIT] <= etiket_i[y*`ADRES_ETIKET_BIT +: `ADRES_ETIKET_BIT];
            blok_mem  [satir_i][y*`L1_BLOK_BIT     +: `L1_BLOK_BIT]       <= blok_i  [y*`L1_BLOK_BIT     +: `L1_BLOK_BIT];
         end
      end
   end

   assign etiket_o  = etiket_mem[satir_r];
   assign blok_o    = blok_mem[satir_r];
   assign gecerli_o = 1'b1;

endmodule

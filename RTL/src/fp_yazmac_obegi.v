`timescale 1ns / 1ps

`include "riscv_controller.vh"

// ===========================================================================
//  fp_yazmac_obegi  -  Kayan nokta yazmac obegi (f0-f31) + scoreboard
// ---------------------------------------------------------------------------
//  yazmac_obegi ile ayni scoreboard mantigi, ANCAK f0 ozel/sifir DEGILDIR
//  (RISC-V'de f0 normal bir yazmactir). Hazard kilidi: rezervasyonda gecerli-bit
//  dusurulur, eslesen etiketle geri-yazmada tekrar yukselir.
// ===========================================================================
module fp_yazmac_obegi (
   input                clk_i,
   input                rst_i,

   input   [4:0]        oku_adres1_i,
   input   [4:0]        oku_adres2_i,
   input   [4:0]        oku_adres3_i,        // FMA ucuncu operand (f[rs3])
   output  [31:0]       oku_veri1_o,
   output               oku_veri1_gecerli_o,
   output  [31:0]       oku_veri2_o,
   output               oku_veri2_gecerli_o,
   output  [31:0]       oku_veri3_o,
   output               oku_veri3_gecerli_o,

   input   [31:0]       yaz_veri_i,
   input   [4:0]        yaz_adres_i,
   input   [3:0]        yaz_etiket_i,
   input                yaz_gecerli_i,

   input   [3:0]        etiket_i,
   input   [4:0]        etiket_adres_i,
   input                etiket_gecerli_i
);

   reg [31:0] yazmac_r [0:31];
   reg [31:0] yazmac_ns [0:31];
   reg [31:0] gecerli_r;
   reg [31:0] gecerli_ns;
   reg [3:0]  etiket_r [0:31];
   reg [3:0]  etiket_ns [0:31];

   integer i;
   always @* begin
      for (i=0;i<32;i=i+1) begin
         yazmac_ns[i]  = yazmac_r[i];
         etiket_ns[i]  = etiket_r[i];
         gecerli_ns[i] = gecerli_r[i];
      end
      if (yaz_gecerli_i) begin
         yazmac_ns[yaz_adres_i]  = yaz_veri_i;
         gecerli_ns[yaz_adres_i] = (etiket_r[yaz_adres_i] == yaz_etiket_i);
      end
      if (etiket_gecerli_i) begin
         etiket_ns[etiket_adres_i]  = etiket_i;
         gecerli_ns[etiket_adres_i] = 1'b0;
      end
   end

   always @(posedge clk_i) begin
      if (!rst_i) begin
         for (i=0;i<32;i=i+1) begin
            gecerli_r[i] <= 1'b1;
            etiket_r[i]  <= 4'b0;
            yazmac_r[i]  <= 32'b0;
         end
      end else begin
         for (i=0;i<32;i=i+1) begin
            gecerli_r[i] <= gecerli_ns[i];
            etiket_r[i]  <= etiket_ns[i];
            yazmac_r[i]  <= yazmac_ns[i];
         end
      end
   end

   assign oku_veri1_o         = yazmac_r[oku_adres1_i];
   assign oku_veri1_gecerli_o = gecerli_r[oku_adres1_i];
   assign oku_veri2_o         = yazmac_r[oku_adres2_i];
   assign oku_veri2_gecerli_o = gecerli_r[oku_adres2_i];
   assign oku_veri3_o         = yazmac_r[oku_adres3_i];
   assign oku_veri3_gecerli_o = gecerli_r[oku_adres3_i];

endmodule

`timescale 1ns / 1ps

`include "riscv_controller.vh"

module dallanma_birimi (
   input   [3:0]                islem_kod_i,
   input   [31:0]               islem_ps_i,
   input   [31:0]               islem_islec_i,
   input   [31:0]               islem_anlik_i,
   input                        islem_atladi_i,
   input                        islem_rvc_i,

   input                        amb_esittir_i,
   input                        amb_kucuktur_i,
   input                        amb_kucuktur_isaretsiz_i,

   output  [31:0]               g1_ps_o,
   output                       g1_ps_gecerli_o,

   output  [31:0]               g2_ps_o,
   output  [31:0]               g2_hedef_ps_o,
   output                       g2_guncelle_o,
   output                       g2_atladi_o,
   output                       g2_hatali_tahmin_o,

   output  [32-1:0]             ps_atlamadi_o
);

reg [31:0]          g1_ps_cmb;
reg                 g1_ps_gecerli_cmb;
reg [31:0]          g2_ps_cmb;
reg [31:0]          g2_hedef_ps_cmb;
reg                 g2_guncelle_cmb;
reg                 g2_atladi_cmb;
reg                 g2_hatali_tahmin_cmb;

reg  [31:0]         toplayici_is0_cmb;
reg  [31:0]         toplayici_is1_cmb;
wire [31:0]         toplayici_sonuc_w;

reg [31:0]          ps_atladi_cmb;
reg [31:0]          ps_atlamadi_cmb;

always @* begin
   g1_ps_cmb                = {32{1'b0}};
   g1_ps_gecerli_cmb        = 1'b0;
   g2_ps_cmb                = {32{1'b0}};
   g2_hedef_ps_cmb          = {32{1'b0}};
   g2_guncelle_cmb          = 1'b0;
   g2_atladi_cmb            = 1'b0;
   g2_hatali_tahmin_cmb     = 1'b0;

   toplayici_is0_cmb        = islem_islec_i;
   toplayici_is1_cmb        = islem_anlik_i;
   ps_atladi_cmb            = toplayici_sonuc_w;

   ps_atlamadi_cmb = islem_rvc_i   ? islem_ps_i + {{32-4{1'b0}}, 4'd2}
                                   : islem_ps_i + {{32-4{1'b0}}, 4'd4};

   case(islem_kod_i)
   `DAL_EQ: begin
      g2_ps_cmb             = islem_ps_i;
      g2_guncelle_cmb       = 1'b1;
      g2_atladi_cmb         = amb_esittir_i;
      g2_hatali_tahmin_cmb  = amb_esittir_i != islem_atladi_i;
      g1_ps_cmb             = g2_atladi_cmb ? ps_atladi_cmb : ps_atlamadi_cmb;
      g1_ps_gecerli_cmb     = g2_hatali_tahmin_cmb;
   end
   `DAL_NE: begin
      g2_ps_cmb             = islem_ps_i;
      g2_guncelle_cmb       = 1'b1;
      g2_atladi_cmb         = !amb_esittir_i;
      g2_hatali_tahmin_cmb  = amb_esittir_i == islem_atladi_i;
      g1_ps_cmb             = g2_atladi_cmb ? ps_atladi_cmb : ps_atlamadi_cmb;
      g1_ps_gecerli_cmb     = g2_hatali_tahmin_cmb;
   end
   `DAL_LT: begin
      g2_ps_cmb             = islem_ps_i;
      g2_guncelle_cmb       = 1'b1;
      g2_atladi_cmb         = amb_kucuktur_i;
      g2_hatali_tahmin_cmb  = amb_kucuktur_i != islem_atladi_i;
      g1_ps_cmb             = g2_atladi_cmb ? ps_atladi_cmb : ps_atlamadi_cmb;
      g1_ps_gecerli_cmb     = g2_hatali_tahmin_cmb;
   end
   `DAL_GE: begin
      g2_ps_cmb             = islem_ps_i;
      g2_guncelle_cmb       = 1'b1;
      g2_atladi_cmb         = !amb_kucuktur_i;
      g2_hatali_tahmin_cmb  = amb_kucuktur_i == islem_atladi_i;
      g1_ps_cmb             = g2_atladi_cmb ? ps_atladi_cmb : ps_atlamadi_cmb;
      g1_ps_gecerli_cmb     = g2_hatali_tahmin_cmb;
   end
   `DAL_LTU: begin
      g2_ps_cmb             = islem_ps_i;
      g2_guncelle_cmb       = 1'b1;
      g2_atladi_cmb         = amb_kucuktur_isaretsiz_i;
      g2_hatali_tahmin_cmb  = amb_kucuktur_isaretsiz_i != islem_atladi_i;
      g1_ps_cmb             = g2_atladi_cmb ? ps_atladi_cmb : ps_atlamadi_cmb;
      g1_ps_gecerli_cmb     = g2_hatali_tahmin_cmb;
   end
   `DAL_GEU: begin
      g2_ps_cmb             = islem_ps_i;
      g2_guncelle_cmb       = 1'b1;
      g2_atladi_cmb         = !amb_kucuktur_isaretsiz_i;
      g2_hatali_tahmin_cmb  = amb_kucuktur_isaretsiz_i == islem_atladi_i;
      g1_ps_cmb             = g2_atladi_cmb ? ps_atladi_cmb : ps_atlamadi_cmb;
      g1_ps_gecerli_cmb     = g2_hatali_tahmin_cmb;
   end
   `DAL_JAL: begin
      g2_ps_cmb             = islem_ps_i;
      g2_guncelle_cmb       = 1'b0;
      g2_atladi_cmb         = 1'b1;
      g2_hatali_tahmin_cmb  = 1'b1;
      g1_ps_cmb             = ps_atladi_cmb;
      g1_ps_gecerli_cmb     = g2_hatali_tahmin_cmb;
   end
   `DAL_JALR: begin
      g2_ps_cmb             = islem_ps_i;
      g2_guncelle_cmb       = 1'b0;
      g2_atladi_cmb         = 1'b1;
      g2_hatali_tahmin_cmb  = 1'b1;
      g1_ps_cmb             = (ps_atladi_cmb) & ~1;
      g1_ps_gecerli_cmb     = g2_hatali_tahmin_cmb;
   end
   endcase

   g2_hedef_ps_cmb          = g2_atladi_cmb ? ps_atladi_cmb : ps_atlamadi_cmb;
end

assign g1_ps_o              = g1_ps_cmb;
assign g1_ps_gecerli_o      = g1_ps_gecerli_cmb;
assign g2_ps_o              = g2_ps_cmb;
assign g2_hedef_ps_o        = g2_hedef_ps_cmb;
assign g2_guncelle_o        = g2_guncelle_cmb;
assign g2_atladi_o          = g2_atladi_cmb;
assign g2_hatali_tahmin_o   = g2_hatali_tahmin_cmb;
assign ps_atlamadi_o        = ps_atlamadi_cmb;

toplayici_birim sum(
   .a_in ( toplayici_is0_cmb ),
   .b_in ( toplayici_is1_cmb ),
   .sum  ( toplayici_sonuc_w )
);


endmodule
`timescale 1ns / 1ps

`include "riscv_controller.vh"

module dallanma_ongorucu (
   input                        clk_i,
   input                        rst_i,

   input   [31:0]               ps_i,
   input                        ps_gecerli_i,

   output                       atladi_o, // Branch taken    
   output  [31:0]               ongoru_o,  // Nereye atlayaca�� --- Getir 1'e giden sinyal

   input   [31:0]               yurut_ps_i,
   input                        yurut_guncelle_i, // dallanma buyru�uysa y�r�tten g�ncelleme gelecek
   input                        yurut_atladi_i, // atlad� mi bilgisi
   input   [31:0]               yurut_atlanan_adres_i, // e�er dallanma atlad�ysa target neresi bilgisi TODO: y�r�te eklenecek
   input                        yurut_hatali_tahmin_i  // hatal� tahmin

);

// --------------------------------------------------------------- //
// -------Valid (1) --- Etiket (27) ----Target (32) -------------- //
reg [`BTB_SATIR_BOYUT-1:0] BTB_r  [0:`BTB_SATIR_SAYISI-1]; // default 32x60
reg [`BTB_SATIR_BOYUT-1:0] BTB_ns [0:`BTB_SATIR_SAYISI-1]; // default 32x60

// --------------------------------------------------------------- //
// -------Etiket (27) ---- Tahmin (2)  --------------------------- //
reg [`BHT_SATIR_BOYUT-1:0] BHT_r  [0:`BHT_SATIR_SAYISI-1]; // defautt 32x29
reg [`BHT_SATIR_BOYUT-1:0] BHT_ns [0:`BHT_SATIR_SAYISI-1]; // defautt 32x29

// -------------------------- 5 Bit ------------------------------ //
reg [`GENEL_GECMIS_YAZMACI_BIT-1:0] GGY_r;
reg [`GENEL_GECMIS_YAZMACI_BIT-1:0] GGY_ns;
reg [31:0]                          dogru_tahmin_sayac_r;
reg [31:0]                          dogru_tahmin_sayac_ns;
reg [31:0]                          yanlis_tahmin_sayac_r;
reg [31:0]                          yanlis_tahmin_sayac_ns;

wire [`BTB_SATIR_BOYUT-1:0]         btb_satir_w;
wire [`BHT_SATIR_BOYUT-1:0]         bht_satir_w;
wire [31:`BTB_PS_BIT]               ps_btb_etiket_w;
wire [31:`BHT_PS_BIT]               ps_bht_etiket_w;
wire [31:`BTB_PS_BIT]               yurut_ps_btb_etiket_w;
wire [31:`BHT_PS_BIT]               yurut_ps_bht_etiket_w;
wire                                btb_valid_w;
wire [32-`BTB_PS_BIT-1:0]           btb_etiket_w;
wire [31:0]                         btb_target_w;
wire [32-`BHT_PS_BIT-1:0]           bht_etiket_w;
wire [`DALLANMA_TAHMIN_BIT-1:0]     bht_dallanma_tahmini_w;
wire                                btb_etiketler_esit_mi_w;
wire                                bht_etiketler_esit_mi_w;
wire [`DALLANMA_TAHMIN_BIT-1:0]     bht_yurut_ps_dallanma_tahmini;

assign btb_satir_w                      = BTB_r [ps_i [`BTB_PS_BIT-1:0]];
assign bht_satir_w                      = BHT_r [ps_i [`BHT_PS_BIT-1:0] ^ GGY_r];
assign ps_btb_etiket_w                  = ps_i [31:`BTB_PS_BIT];
assign ps_bht_etiket_w                  = ps_i [31:`BHT_PS_BIT];
assign yurut_ps_btb_etiket_w            = yurut_ps_i [31:`BTB_PS_BIT];
assign yurut_ps_bht_etiket_w            = yurut_ps_i [31:`BHT_PS_BIT];
assign btb_valid_w                      = btb_satir_w [`BTB_VALID_BITI];
assign btb_etiket_w                     = btb_satir_w [`BTB_VALID_BITI-1:32];
assign btb_target_w                     = btb_satir_w [31:0];
assign bht_etiket_w                     = bht_satir_w [`DALLANMA_TAHMIN_BIT +: 27];
assign bht_dallanma_tahmini_w           = bht_satir_w [`DALLANMA_TAHMIN_BIT-1:0];
assign btb_etiketler_esit_mi_w          = ps_btb_etiket_w == btb_etiket_w;
assign bht_etiketler_esit_mi_w          = ps_bht_etiket_w == bht_etiket_w;
assign bht_yurut_ps_dallanma_tahmini    = BHT_r [yurut_ps_i[`BHT_PS_BIT-1:0]^GGY_r][`DALLANMA_TAHMIN_BIT-1:0];

//............................................//
//.......... 11 --> G��l� Atlar    .......... //
//.......... 10 --> Zay�f Atlar    .......... //
//.......... 01 --> Zay�f Atlamaz  .......... //
//.......... 00 --> G��l� Atlamaz  .......... //

localparam GUCLU_ATLAR      = 3;
localparam ZAYIF_ATLAR      = 2;
localparam ZAYIF_ATLAMAZ    = 1;
localparam GUCLU_ATLAMAZ    = 0;

assign atladi_o = ps_gecerli_i && btb_valid_w && btb_etiketler_esit_mi_w && bht_etiketler_esit_mi_w && 
                 ((bht_dallanma_tahmini_w == GUCLU_ATLAR) || ((bht_dallanma_tahmini_w == ZAYIF_ATLAR))) && (btb_target_w!=0);
assign ongoru_o = btb_target_w;

integer i;
always @* begin 
    GGY_ns                  = GGY_r;
    dogru_tahmin_sayac_ns   = dogru_tahmin_sayac_r;
    yanlis_tahmin_sayac_ns  = yanlis_tahmin_sayac_r;
    for (i = 0; i < `BTB_SATIR_SAYISI; i = i + 1) begin
     BTB_ns[i] = BTB_r[i];
    end
    for (i = 0; i < `BHT_SATIR_SAYISI; i = i + 1) begin
     BHT_ns[i] = BHT_r[i];
    end
    
    if (yurut_guncelle_i) begin
      GGY_ns = {GGY_r [`GENEL_GECMIS_YAZMACI_BIT-2:0], yurut_atladi_i}; 
      if (yurut_atladi_i) begin
      BTB_ns [yurut_ps_i[`BTB_PS_BIT-1:0]][`BTB_VALID_BITI]         = 1'b1; // ;BTB_VALID_BITI G�NCELLEMES�
      BTB_ns [yurut_ps_i[`BTB_PS_BIT-1:0]][`BTB_VALID_BITI-1:32]    = yurut_ps_btb_etiket_w; // BTB_ETIKET G�NCELLEMES�
      BTB_ns [yurut_ps_i[`BTB_PS_BIT-1:0]][31:0]                    = yurut_atlanan_adres_i; // SADECE ATLADIYSA TARGET G�NCELLENMEL�, ATLAMADIYSA 0 YAPMALI MIYIZ???
      end
      BHT_ns [yurut_ps_i[`BHT_PS_BIT-1:0]^GGY_r][`BHT_SATIR_BOYUT-1:`DALLANMA_TAHMIN_BIT]   = yurut_ps_bht_etiket_w; // BHT_ETIKET 
      BHT_ns [yurut_ps_i[`BHT_PS_BIT-1:0]^GGY_r][`DALLANMA_TAHMIN_BIT-1:0]                  = yurut_atladi_i ? // BHT_DALLANMA_TAHMINI G�NCELLEMES�
                                              (bht_yurut_ps_dallanma_tahmini == 3 ? 3 : bht_yurut_ps_dallanma_tahmini + 1) :
                                              (bht_yurut_ps_dallanma_tahmini == 0 ? 0 : bht_yurut_ps_dallanma_tahmini - 1);  
      dogru_tahmin_sayac_ns  = yurut_hatali_tahmin_i ? dogru_tahmin_sayac_r      : dogru_tahmin_sayac_r + 1;
      yanlis_tahmin_sayac_ns = yurut_hatali_tahmin_i ? yanlis_tahmin_sayac_r + 1 : yanlis_tahmin_sayac_r;        
    end
end

always @ (posedge clk_i) begin
   if (!rst_i) begin
      for (i = 0; i < `BTB_SATIR_SAYISI; i = i + 1) begin
         BTB_r[i] <= 0;
      end
      for (i = 0; i < `BHT_SATIR_SAYISI; i = i + 1) begin
         BHT_r[i] <= 0;
      end
      GGY_r                 <= 0;
      dogru_tahmin_sayac_r  <= 0;
      yanlis_tahmin_sayac_r <= 0;    
   end
   else begin
      for (i = 0; i < `BTB_SATIR_SAYISI; i = i + 1) begin
         BTB_r[i] <= BTB_ns[i];
      end
      for (i = 0; i < `BHT_SATIR_SAYISI; i = i + 1) begin
         BHT_r[i] <= BHT_ns[i];
      end
      GGY_r                 <= GGY_ns; 
      dogru_tahmin_sayac_r  <= dogru_tahmin_sayac_ns;
      yanlis_tahmin_sayac_r <= yanlis_tahmin_sayac_ns;
   end
end
endmodule

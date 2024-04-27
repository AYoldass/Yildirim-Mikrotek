`timescale 1ns / 1ps

`include "riscv_controller.vh"

module getir_asama2(
   input                       clk_i,
   input                       rst_i,

   input                       g1_istek_yapildi_i,

   input   [31:0]              g1_ps_i,
   input                       g1_ps_gecerli_i,
   output                      g1_ps_hazir_o,

   output  [31:0]              g1_dallanma_ps_o,
   output                      g1_dallanma_gecerli_o,

   input   [31:0]              yurut_ps_i,
   input   [31:0]              yurut_hedef_ps_i,
   input                       yurut_guncelle_i,
   input                       yurut_atladi_i,
   input                       yurut_hatali_tahmin_i,

   input   [31:0]              l1b_buyruk_i,
   input                       l1b_buyruk_gecerli_i,
   output                      l1b_buyruk_hazir_o,

   output  [31:0]              coz_buyruk_o,
   output  [31:0]              coz_buyruk_ps_o,
   output                      coz_buyruk_gecerli_o,
   output                      coz_buyruk_atladi_o,

   input                       cek_bosalt_i,
   input                       cek_duraklat_i
);


reg     [8:0]               l1b_beklenen_sayisi_r;
reg     [8:0]               l1b_beklenen_sayisi_ns;

reg     [8:0]               g2_bos_istek_sayaci_r;
reg     [8:0]               g2_bos_istek_sayaci_ns;

reg     [31:0]              coz_buyruk_r;
reg     [31:0]              coz_buyruk_ns;

reg     [31:0]              coz_buyruk_ps_r;
reg     [31:0]              coz_buyruk_ps_ns;

reg                         coz_buyruk_gecerli_r;
reg                         coz_buyruk_gecerli_ns;

reg                         l1b_buyruk_hazir_cmb;
reg                         g1_ps_hazir_cmb;

reg                         duraklat_past_r;

reg     [1:0]               g2_durum_r;
reg     [1:0]               g2_durum_ns;

reg     [31:0]              g1_bosalt_hedef_ps_r;
reg     [31:0]              g1_bosalt_hedef_ps_ns;

reg                         g1_bosalt_aktif_r;
reg                         g1_bosalt_aktif_ns;

reg                         duraklat_istek_yapildi_r;
reg                         duraklat_istek_yapildi_ns;

wire    [31:0]              l1b_obek_ps_w;


reg     [31:0]              buf_buyruk_r;
reg     [31:0]              buf_buyruk_ns;

reg     [31:0]              buf_ps_r;
reg     [31:0]              buf_ps_ns;

reg                         ilk_buyruk_r;
reg                         ilk_buyruk_ns;

reg                         branch_req_r;
reg                         branch_req_ns;

// Dallanma Ongorucu
wire   [31:0]           do_ps_w;
wire                    do_ps_gecerli_w;
wire                    do_atladi_w;
wire   [31:0]           do_ongoru_w;
wire   [31:0]           do_yurut_ps_w;
wire                    do_yurut_guncelle_w;
wire                    do_yurut_atladi_w;
wire   [31:0]           do_yurut_atlanan_adres_w;
wire                    do_yurut_hatali_tahmin_w;


localparam                  G2_YAZMAC_BOS   = 2'd0;
localparam                  G2_YAZMAC_YARIM = 2'd1;
localparam                  G2_YAZMAC_DOLU  = 2'd2;
localparam                  G2_CEK_BOSALT   = 2'd3;


always @* begin
   branch_req_ns                = cek_duraklat_i && (branch_req_r || g1_istek_yapildi_i);
   l1b_beklenen_sayisi_ns       = l1b_beklenen_sayisi_r;
   coz_buyruk_ns                = coz_buyruk_r;
   coz_buyruk_ps_ns             = coz_buyruk_ps_r;
   coz_buyruk_gecerli_ns        = cek_duraklat_i ? coz_buyruk_gecerli_r : 1'b0;
   // coz_buyruk_atladi_ns = cek_duraklat_i ? coz_buyruk_atladi_r : 1'b0;
   l1b_buyruk_hazir_cmb         = 1'b0;
   g1_ps_hazir_cmb              = 1'b0;
   g2_durum_ns                  = g2_durum_r;
   g2_bos_istek_sayaci_ns       = g2_bos_istek_sayaci_r;
   buf_ps_ns                    = buf_ps_r;
   buf_buyruk_ns                = buf_buyruk_r;
   ilk_buyruk_ns                = ilk_buyruk_r;
   duraklat_istek_yapildi_ns    = cek_duraklat_i ? duraklat_istek_yapildi_r : g1_istek_yapildi_i;
   g1_bosalt_hedef_ps_ns        = g1_dallanma_gecerli_o ? g1_dallanma_ps_o : g1_bosalt_hedef_ps_r;
   g1_bosalt_aktif_ns           = g1_bosalt_aktif_r;

   if (g2_durum_r != G2_CEK_BOSALT) begin
      // Istek yapildiysa ve su an kabul etmiyorsak cevap beklenen istek sayisi 1 artar.
      if (g1_istek_yapildi_i && !(l1b_buyruk_hazir_o && l1b_buyruk_gecerli_i)) begin
         l1b_beklenen_sayisi_ns = l1b_beklenen_sayisi_r + 1;
      end
      // Istek yapilmadiysa ve su an bir istek kabul ediyorsak cevap beklenen istek sayisi 1 azalir.
      if (!g1_istek_yapildi_i && (l1b_buyruk_hazir_o && l1b_buyruk_gecerli_i)) begin
         l1b_beklenen_sayisi_ns = l1b_beklenen_sayisi_r - 1;
      end
      g1_ps_hazir_cmb = l1b_buyruk_gecerli_i && g1_ps_gecerli_i && !cek_duraklat_i;
      l1b_buyruk_hazir_cmb = l1b_buyruk_gecerli_i && g1_ps_gecerli_i && !cek_duraklat_i;
   end

   ilk_buyruk_ns = ilk_buyruk_r && (cek_duraklat_i || !coz_buyruk_gecerli_ns);
   if (coz_buyruk_atladi_o && !cek_duraklat_i) begin
      coz_buyruk_gecerli_ns = 1'b0;
      ilk_buyruk_ns = 1'b1;
      g1_bosalt_aktif_ns = 1'b1;
      l1b_beklenen_sayisi_ns = branch_req_r + g1_istek_yapildi_i;
      g2_durum_ns = g2_durum_r == G2_CEK_BOSALT ? G2_CEK_BOSALT : G2_YAZMAC_BOS;
      if (l1b_beklenen_sayisi_r > branch_req_r) begin
         g1_ps_hazir_cmb = g1_dallanma_ps_o != g1_ps_i;
         g2_bos_istek_sayaci_ns = g2_bos_istek_sayaci_r + l1b_beklenen_sayisi_r - l1b_buyruk_hazir_cmb - branch_req_r;
         g2_durum_ns = g2_bos_istek_sayaci_ns == 0 ? G2_YAZMAC_BOS : G2_CEK_BOSALT;
      end
   end

   if (cek_bosalt_i && !cek_duraklat_i) begin
      ilk_buyruk_ns = 1'b1;
      g2_durum_ns = g2_bos_istek_sayaci_r != 3'd0 && !l1b_buyruk_gecerli_i ? G2_CEK_BOSALT : G2_YAZMAC_BOS;
      l1b_beklenen_sayisi_ns = g1_istek_yapildi_i ? 3'd1 : 3'd0;
      coz_buyruk_gecerli_ns = 1'b0;
//        coz_buyruk_atladi_ns = 1'b0;
      g1_ps_hazir_cmb = 1'b0;
      g1_bosalt_aktif_ns = 1'b0;
      if (l1b_beklenen_sayisi_r != 0) begin
         l1b_buyruk_hazir_cmb = 1'b1;
         if (l1b_buyruk_gecerli_i) begin
            g2_bos_istek_sayaci_ns = g2_bos_istek_sayaci_r + l1b_beklenen_sayisi_r - 1;
            g2_durum_ns = g2_bos_istek_sayaci_ns > 0 ? G2_CEK_BOSALT : G2_YAZMAC_BOS;
         end
         else begin
            g2_bos_istek_sayaci_ns = g2_bos_istek_sayaci_r + l1b_beklenen_sayisi_r;
            g2_durum_ns = G2_CEK_BOSALT;
         end
      end
   end
end

always @(posedge clk_i) begin
   if (!rst_i) begin
      g2_durum_r                <= G2_YAZMAC_BOS;
      l1b_beklenen_sayisi_r     <= 2'd0;
      g2_bos_istek_sayaci_r     <= 2'd0;
      coz_buyruk_r              <= 32'h0;
      coz_buyruk_ps_r           <= 32'h0;
      coz_buyruk_gecerli_r      <= 1'b0;
      buf_buyruk_r              <= 32'h0;
      buf_ps_r                  <= 32'h0;
      ilk_buyruk_r              <= 1'b1;
//        coz_buyruk_atladi_r <= 1'b0;
      duraklat_istek_yapildi_r  <= 1'b0;
      g1_bosalt_hedef_ps_r      <= 32'h0;
      g1_bosalt_aktif_r         <= 1'b0;
      duraklat_past_r           <= 1'b0;
      branch_req_r              <= 1'b0;
   end
   else begin
      g2_durum_r                <= g2_durum_ns;
      l1b_beklenen_sayisi_r     <= l1b_beklenen_sayisi_ns;
      g2_bos_istek_sayaci_r     <= g2_bos_istek_sayaci_ns;
      coz_buyruk_r              <= coz_buyruk_ns;
      coz_buyruk_ps_r           <= coz_buyruk_ps_ns;
      coz_buyruk_gecerli_r      <= coz_buyruk_gecerli_ns;
      // coz_buyruk_atladi_r <= coz_buyruk_atladi_ns;
      buf_buyruk_r              <= buf_buyruk_ns;
      buf_ps_r                  <= buf_ps_ns;
      ilk_buyruk_r              <= ilk_buyruk_ns;
      duraklat_istek_yapildi_r  <= duraklat_istek_yapildi_ns;
      g1_bosalt_hedef_ps_r      <= g1_bosalt_hedef_ps_ns;
      g1_bosalt_aktif_r         <= g1_bosalt_aktif_ns;
      duraklat_past_r           <= cek_duraklat_i;
      branch_req_r              <= branch_req_ns;
   end
end

assign g1_dallanma_ps_o             = do_ongoru_w;
assign g1_dallanma_gecerli_o        = do_atladi_w && !duraklat_past_r;
assign g1_ps_hazir_o                = g1_ps_hazir_cmb;
assign l1b_buyruk_hazir_o           = l1b_buyruk_hazir_cmb;
assign coz_buyruk_o                 = coz_buyruk_r;
assign coz_buyruk_ps_o              = coz_buyruk_ps_r;
assign coz_buyruk_gecerli_o         = coz_buyruk_gecerli_r;
assign coz_buyruk_atladi_o          = do_atladi_w && coz_buyruk_gecerli_r;

assign l1b_obek_ps_w                = g1_ps_i & 32'hFFFF_FFFC;


reg [31:0] stall_ctr_r;

always @(posedge clk_i) begin
   if (!rst_i) begin
      stall_ctr_r <= 0;
   end
   else begin
      if (coz_buyruk_gecerli_o) begin
         stall_ctr_r <= 0;
      end
      else begin
         stall_ctr_r <= stall_ctr_r + 1;
      end
   end
end

// ila_getir2 dbg_getir2 (
//     .clk    ( clk_i ),
//     .probe0 ( stall_ctr_r ),
//     .probe1 ( coz_buyruk_r ),
//     .probe2 ( coz_buyruk_ps_r ),
//     .probe3 ( coz_buyruk_gecerli_r )
// );

dallanma_ongorucu do (
   .clk_i                    ( clk_i ),
   .rst_i                    ( rst_i ),
   .ps_i                     ( do_ps_w ),
   .ps_gecerli_i             ( do_ps_gecerli_w ),
   .atladi_o                 ( do_atladi_w ), 
   .ongoru_o                 ( do_ongoru_w ), 
   .yurut_ps_i               ( do_yurut_ps_w ),
   .yurut_guncelle_i         ( do_yurut_guncelle_w ),
   .yurut_atladi_i           ( do_yurut_atladi_w ),
   .yurut_atlanan_adres_i    ( do_yurut_atlanan_adres_w ),
   .yurut_hatali_tahmin_i    ( do_yurut_hatali_tahmin_w )
);

assign do_ps_w                  = coz_buyruk_ps_r;
assign do_ps_gecerli_w          = coz_buyruk_gecerli_r;
assign do_yurut_ps_w            = yurut_ps_i;
assign do_yurut_guncelle_w      = yurut_guncelle_i;
assign do_yurut_atladi_w        = yurut_atladi_i;
assign do_yurut_atlanan_adres_w = yurut_hedef_ps_i;
assign do_yurut_hatali_tahmin_w = yurut_hatali_tahmin_i;

endmodule
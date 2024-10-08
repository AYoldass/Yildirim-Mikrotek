`timescale 1ns / 1ps

`include "riscv_controller.vh"

module veri_yolu_denetleyici (
   input                           clk_i,
   input                           rstn_i,

   // vy denetleyici istek <-> bellek
   output  [31:0]                  mem_istek_adres_o,
   output  [31:0]                  mem_istek_veri_o,
   output                          mem_istek_yaz_o,
   output                          mem_istek_gecerli_o,
   input                           mem_istek_hazir_i,

   // bellek yanit <-> vy denetleyici
   input   [31:0]                  mem_veri_i,
   input                           mem_veri_gecerli_i,
   output                          mem_veri_hazir_o,

   // l1b denetleyici istek <-> vy denetleyici 
   input   [31:0]                  l1b_istek_adres_i,
   input                           l1b_istek_gecerli_i,
   input   [31:0]                  l1b_istek_veri_i,
   input                           l1b_istek_yaz_i,
   output                          l1b_istek_hazir_o,

   // vy denetleyici yanit <-> l1b denetleyici
   output  [31:0]                  l1b_veri_o,
   output                          l1b_veri_gecerli_o,
   input                           l1b_veri_hazir_i,

   // l1v denetleyici istek <-> vy denetleyici 
   input   [31:0]                  l1v_istek_adres_i,
   input                           l1v_istek_gecerli_i,
   input                           l1v_istek_onbellekleme_i,
   input   [31:0]                  l1v_istek_veri_i,
   input                           l1v_istek_yaz_i,
   output                          l1v_istek_hazir_o,

   // vy denetleyici yanit <-> l1v denetleyici
   output  [31:0]                  l1v_veri_o,
   output                          l1v_veri_gecerli_o,
   input                           l1v_veri_hazir_i
);

localparam VY_DURUM_BIT         = 3;
localparam VY_BOSTA             = 'd0;
localparam VY_BLOK_OKU_ISTEK    = 'd1;
localparam VY_BLOK_OKU_BEKLE    = 'd2;
localparam VY_BLOK_OKU_YANIT    = 'd3;
localparam VY_BLOK_YAZ          = 'd4;
localparam VY_IKI_ISTEK         = 'd5;

reg  [31:0]                 mem_istek_adres_r;
reg  [31:0]                 mem_istek_adres_ns;

reg  [31:0]                 mem_istek_veri_r;
reg  [31:0]                 mem_istek_veri_ns;

reg                         mem_istek_yaz_r;
reg                         mem_istek_yaz_ns;

reg                         mem_istek_gecerli_r;
reg                         mem_istek_gecerli_ns;

reg                         mem_veri_hazir_r;
reg                         mem_veri_hazir_ns;

reg [VY_DURUM_BIT-1:0]      vy_durum_r;
reg [VY_DURUM_BIT-1:0]      vy_durum_ns;

reg                         l1_istek_hazir_r;
reg                         l1_istek_hazir_ns;

reg [31:0]                  l1_veri_r;
reg [31:0]                  l1_veri_ns;

reg                         l1_veri_gecerli_r;
reg                         l1_veri_gecerli_ns;

reg                         l1b_sec_r;
reg                         l1b_sec_ns;

reg                         iki_istek_r;
reg                         iki_istek_ns;

reg  [31:0]                 iki_istek_adres_r;
reg  [31:0]                 iki_istek_adres_ns;

reg  [31:0]                 iki_istek_veri_r;
reg  [31:0]                 iki_istek_veri_ns;

reg                         iki_istek_yaz_r;
reg                         iki_istek_yaz_ns;

reg                         iki_istek_onbellekleme_r;
reg                         iki_istek_onbellekleme_ns;

wire                        l1_istek_hazir_w;
wire [31:0]                 l1_veri_w;
wire                        l1_veri_gecerli_w;

wire [31:0]                 l1_istek_adres_w;
wire                        l1_istek_gecerli_w;
wire [31:0]                 l1_istek_veri_w;
wire                        l1_istek_yaz_w;
wire                        l1_veri_hazir_w;

localparam BLOK_VERI_SAYISI = 32 / 32;

reg [31:0]  vy_buffer_blok_r;
reg [31:0]  vy_buffer_blok_ns;

reg [$clog2(BLOK_VERI_SAYISI)-1:0] vy_buffer_indis_r;
reg [$clog2(BLOK_VERI_SAYISI)-1:0] vy_buffer_indis_ns;

reg [$clog2(BLOK_VERI_SAYISI)-1:0] vy_istek_indis_r;
reg [$clog2(BLOK_VERI_SAYISI)-1:0] vy_istek_indis_ns;

reg [$clog2(BLOK_VERI_SAYISI)-1:0] vy_dur_indis_r;
reg [$clog2(BLOK_VERI_SAYISI)-1:0] vy_dur_indis_ns;

always @* begin
   vy_durum_ns              = vy_durum_r;
   l1_veri_ns               = l1_veri_r;
   l1_veri_gecerli_ns       = l1_veri_gecerli_r;
   vy_buffer_blok_ns        = vy_buffer_blok_r;
   vy_buffer_indis_ns       = vy_buffer_indis_r; 
   vy_istek_indis_ns        = vy_istek_indis_r; 
   vy_dur_indis_ns          = vy_dur_indis_r;
   mem_istek_adres_ns       = mem_istek_adres_r;
   mem_istek_veri_ns        = mem_istek_veri_r;
   mem_istek_yaz_ns         = mem_istek_yaz_r;
   mem_istek_gecerli_ns     = mem_istek_gecerli_r;
   mem_veri_hazir_ns        = mem_veri_hazir_r;
   l1b_sec_ns               = l1b_sec_r;
   iki_istek_ns             = iki_istek_r;
   iki_istek_adres_ns       = iki_istek_adres_r;
   iki_istek_yaz_ns         = iki_istek_yaz_r;
   iki_istek_veri_ns        = iki_istek_veri_r;
   iki_istek_onbellekleme_ns = iki_istek_onbellekleme_r;
 
   case (vy_durum_r)
   VY_BOSTA: begin
      l1_istek_hazir_ns  = 1'b1;
      vy_buffer_indis_ns = 0;
      vy_istek_indis_ns  = 0;
      
      if ((l1b_istek_hazir_o && l1b_istek_gecerli_i) && (l1v_istek_hazir_o && l1v_istek_gecerli_i)) begin
         l1b_sec_ns         = 1'b1;
         l1_istek_hazir_ns  = 1'b0;
         mem_istek_adres_ns = l1b_istek_adres_i;
         vy_dur_indis_ns    = BLOK_VERI_SAYISI - 1;
         if (l1b_istek_yaz_i) begin
            vy_buffer_blok_ns = l1b_istek_veri_i;
            vy_durum_ns       = VY_BLOK_YAZ;
         end
         else begin
            vy_durum_ns = VY_BLOK_OKU_ISTEK;
         end

         iki_istek_ns              = 1'b1;
         iki_istek_adres_ns        = l1v_istek_adres_i;
         iki_istek_yaz_ns          = l1v_istek_yaz_i;
         iki_istek_veri_ns         = l1v_istek_veri_i;
         iki_istek_onbellekleme_ns = l1v_istek_onbellekleme_i;
      end
      else if (l1b_istek_hazir_o && l1b_istek_gecerli_i) begin
         l1b_sec_ns         = 1'b1;
         l1_istek_hazir_ns  = 1'b0;
         mem_istek_adres_ns = l1b_istek_adres_i;
         vy_dur_indis_ns    = BLOK_VERI_SAYISI - 1;
         if (l1b_istek_yaz_i) begin
            vy_buffer_blok_ns = l1b_istek_veri_i;
            vy_durum_ns       = VY_BLOK_YAZ;
         end
         else begin
            vy_durum_ns = VY_BLOK_OKU_ISTEK;
         end
      end
      else if (l1v_istek_hazir_o && l1v_istek_gecerli_i) begin
         l1b_sec_ns         = 1'b0;
         l1_istek_hazir_ns  = 1'b0;
         mem_istek_adres_ns = l1v_istek_adres_i;
         vy_dur_indis_ns    = l1v_istek_onbellekleme_i ? 0 : BLOK_VERI_SAYISI - 1;
         if (l1v_istek_yaz_i) begin
            vy_buffer_blok_ns = l1v_istek_veri_i;
            vy_durum_ns       = VY_BLOK_YAZ;
         end
         else begin
            vy_durum_ns = VY_BLOK_OKU_ISTEK;
         end
      end
   end
   
   VY_BLOK_OKU_ISTEK: begin
   // Bu durum icerisinde istek yapma ve veri kabul etme asenkron calisiyor.
   // O nedenle tum isteklerimizi bitirdigimizde VY_BLOK_BEKLE durumuna gidilmeli.
      mem_istek_adres_ns    = mem_istek_adres_r;
      mem_istek_veri_ns     = vy_buffer_blok_r[vy_istek_indis_r];
      mem_istek_gecerli_ns  = 1'b1;
      mem_istek_yaz_ns      = 1'b0;
      if (mem_istek_hazir_i && mem_istek_gecerli_o) begin
         mem_istek_adres_ns = mem_istek_adres_r + 4;
         vy_istek_indis_ns  = vy_istek_indis_r + 1;
         if (vy_istek_indis_r == vy_dur_indis_r) begin
            mem_istek_gecerli_ns = 1'b0;
            vy_durum_ns = VY_BLOK_OKU_BEKLE;
         end
      end

      mem_veri_hazir_ns = 1'b1;
      if (mem_veri_hazir_o && mem_veri_gecerli_i) begin
         vy_buffer_blok_ns[vy_buffer_indis_r * 32 +: 32] = mem_veri_i;
         vy_buffer_indis_ns = vy_buffer_indis_r + 1;
         if (vy_buffer_indis_r == vy_dur_indis_r) begin
            mem_veri_hazir_ns = 1'b0;
            l1_veri_ns          = vy_buffer_blok_ns;
            l1_veri_gecerli_ns  = 1'b1;
            vy_durum_ns         = VY_BLOK_OKU_YANIT;
         end
      end
   end
   VY_BLOK_OKU_BEKLE: begin
      // Istek yaptigimiz veriye karsi hazir olmamak gibi bir luksumuz yok.
      // Gelecekte farkli bellek tipleriyle uyumlu olmasi icin bu sinyallerle yazdim.
      mem_veri_hazir_ns = 1'b1;
      if (mem_veri_hazir_o && mem_veri_gecerli_i) begin
         vy_buffer_blok_ns[vy_buffer_indis_r * 32 +: 32] = mem_veri_i;
         vy_buffer_indis_ns = vy_buffer_indis_r  + 1;
         if (vy_buffer_indis_r == vy_dur_indis_r) begin
            mem_veri_hazir_ns   = 1'b0;
            l1_veri_ns          = vy_buffer_blok_ns;
            l1_veri_gecerli_ns  = 1'b1;
            vy_durum_ns         = VY_BLOK_OKU_YANIT;
         end
      end
   end
   
   VY_BLOK_OKU_YANIT: begin
      l1_veri_ns            = vy_buffer_blok_r;
      l1_veri_gecerli_ns    = 1'b1;
      if (l1_veri_hazir_w && l1_veri_gecerli_w) begin
         l1_veri_gecerli_ns = 1'b0;
         vy_durum_ns        = iki_istek_r ? VY_IKI_ISTEK : VY_BOSTA;
      end
   end
   
   VY_BLOK_YAZ: begin
      mem_istek_adres_ns    = mem_istek_adres_r;
      mem_istek_veri_ns     = vy_buffer_blok_r[vy_istek_indis_r * 32 +: 32];
      mem_istek_gecerli_ns  = 1'b1;
      mem_istek_yaz_ns      = 1'b1;
      if (mem_istek_hazir_i && mem_istek_gecerli_o) begin
         mem_istek_adres_ns = mem_istek_adres_r + 4;
         mem_istek_veri_ns  = vy_buffer_blok_r[(vy_istek_indis_r + 1) * 32 +: 32];
         vy_istek_indis_ns  = vy_istek_indis_r + 1;
         if (vy_istek_indis_r == vy_dur_indis_r) begin
            mem_istek_gecerli_ns    = 1'b0;
            mem_istek_yaz_ns        = 1'b0;
            vy_durum_ns = iki_istek_r ? VY_IKI_ISTEK : VY_BOSTA;
         end
      end
   end
   
   VY_IKI_ISTEK: begin
      l1b_sec_ns            = 1'b0;
      mem_istek_adres_ns    = iki_istek_adres_r;
      vy_dur_indis_ns       = iki_istek_onbellekleme_r ? 0 : BLOK_VERI_SAYISI - 1;
      vy_buffer_indis_ns    = 0;
      vy_istek_indis_ns     = 0;
      
      if (iki_istek_yaz_r) begin
         vy_buffer_blok_ns  = iki_istek_veri_r;
         vy_durum_ns        = VY_BLOK_YAZ;
      end
      else begin
         vy_durum_ns = VY_BLOK_OKU_ISTEK;
      end

      iki_istek_ns              = 1'b0;
      iki_istek_onbellekleme_ns = 1'b0;
   end
   endcase

   l1_istek_hazir_ns = vy_durum_ns == VY_BOSTA;
end

always @(posedge clk_i) begin
   if (!rstn_i) begin
      vy_durum_r                <= VY_BOSTA;
      l1_istek_hazir_r          <= 0;
      l1_veri_r                 <= 0;
      l1_veri_gecerli_r         <= 0;
      vy_buffer_blok_r          <= 0;
      vy_buffer_indis_r         <= 0;
      vy_istek_indis_r          <= 0;
      vy_dur_indis_r            <= 0;
      mem_istek_adres_r         <= 0;
      mem_istek_veri_r          <= 0;
      mem_istek_yaz_r           <= 0;
      mem_istek_gecerli_r       <= 0;
      mem_veri_hazir_r          <= 0;
      l1b_sec_r                 <= 0;
      iki_istek_r               <= 0;
      iki_istek_adres_r         <= 0;
      iki_istek_yaz_r           <= 0;
      iki_istek_veri_r          <= 0;
      iki_istek_onbellekleme_r  <= 0;
   end
   else begin
      vy_durum_r                <= vy_durum_ns;
      l1_istek_hazir_r          <= l1_istek_hazir_ns;
      l1_veri_r                 <= l1_veri_ns;
      l1_veri_gecerli_r         <= l1_veri_gecerli_ns;
      vy_buffer_blok_r          <= vy_buffer_blok_ns;
      vy_buffer_indis_r         <= vy_buffer_indis_ns;
      vy_istek_indis_r          <= vy_istek_indis_ns;
      vy_dur_indis_r            <= vy_dur_indis_ns;
      mem_istek_adres_r         <= mem_istek_adres_ns;
      mem_istek_veri_r          <= mem_istek_veri_ns;
      mem_istek_yaz_r           <= mem_istek_yaz_ns;
      mem_istek_gecerli_r       <= mem_istek_gecerli_ns;
      mem_veri_hazir_r          <= mem_veri_hazir_ns;
      l1b_sec_r                 <= l1b_sec_ns;
      iki_istek_r               <= iki_istek_ns;
      iki_istek_adres_r         <= iki_istek_adres_ns;
      iki_istek_yaz_r           <= iki_istek_yaz_ns;
      iki_istek_veri_r          <= iki_istek_veri_ns;
      iki_istek_onbellekleme_r  <= iki_istek_onbellekleme_ns;
   end
end

assign l1_istek_hazir_w     = l1_istek_hazir_r;
assign l1_veri_w            = l1_veri_r;
assign l1_veri_gecerli_w    = l1_veri_gecerli_r;

assign l1_istek_adres_w     = l1b_sec_r ? l1b_istek_adres_i   : l1v_istek_adres_i;
assign l1_istek_gecerli_w   = l1b_sec_r ? l1b_istek_gecerli_i : l1v_istek_gecerli_i;
assign l1_istek_veri_w      = l1b_sec_r ? l1b_istek_veri_i    : l1v_istek_veri_i;
assign l1_istek_yaz_w       = l1b_sec_r ? l1b_istek_yaz_i     : l1v_istek_yaz_i;
assign l1_veri_hazir_w      = l1b_sec_r ? l1b_veri_hazir_i    : l1v_veri_hazir_i;

assign l1b_veri_o           = l1_veri_w;
assign l1b_istek_hazir_o    = l1_istek_hazir_w;
assign l1b_veri_gecerli_o   = l1b_sec_r ? l1_veri_gecerli_w : 1'b0;

assign l1v_veri_o           = l1_veri_w;
assign l1v_istek_hazir_o    = l1_istek_hazir_w;
assign l1v_veri_gecerli_o   = l1b_sec_r ? 1'b0 : l1_veri_gecerli_w;

assign mem_istek_adres_o    = mem_istek_adres_r;
assign mem_istek_veri_o     = mem_istek_veri_r;
assign mem_istek_yaz_o      = mem_istek_yaz_r;
assign mem_istek_gecerli_o  = mem_istek_gecerli_r;
assign mem_veri_hazir_o     = mem_veri_hazir_r;

endmodule
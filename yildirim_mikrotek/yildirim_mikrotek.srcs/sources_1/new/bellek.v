`timescale 1ns / 1ps

`include "riscv_controller.vh"

module bellek(
   input                       clk_i,
   input                       rst_i,

   // l1v istek <> bellek
   output  [31:0]              l1v_istek_adres_o,
   output                      l1v_istek_gecerli_o,
   output                      l1v_istek_onbellekleme_o,
   output                      l1v_istek_yaz_o,
   output  [31:0]              l1v_istek_veri_o,
   output  [3:0]               l1v_istek_maske_o,
   input                       l1v_istek_hazir_i,

   // Yazmc oku sonuna veri yonlendirmesi
   output  [31:0]              yo_veri_o,
   output  [4:0]               yo_adres_o,
   output  [3:0]               yo_etiket_o,
   output                      yo_gecerli_o,

   // l1v yanit <> bellek
   input   [31:0]              l1v_veri_i,
   input                       l1v_veri_gecerli_i,
   output                      l1v_veri_hazir_o,

   output                      duraklat_o,

   input   [218:0]             bellek_i,
   output  [218:0]             geri_yaz_o
);

reg [218:0]                    r;
reg [218:0]                    ns;

wire [31:0]                    ps_w;
wire [3:0]                     tag_w;
wire                           taken_w;

wire                           gecerli_w;
wire [3:0]                     buyruk_secim_w;
wire [31:0]                    rs1_w;
wire [31:0]                    rs2_w;
wire [31:0]                    imm_w;
wire [31:0]                    rd_w;

wire                           vyb_hazir_w;
wire [3:0]                     maske_w;

wire                           oku_w;
wire                           yaz_w;

// veri yolu birimine gidecek olanlar

wire                    bib_istek_gecerli_w;
wire                    bib_istek_yaz_w;
wire [31:0]             bib_veri_w;
wire                    bib_istek_oku_w;
wire [31:0]             bib_istek_adres_w;
wire [3:0]              bib_istek_maske_w;
wire [31:0]             bellek_veri_w;
wire                    bellek_gecerli_w;

wire [1:0]              bayt_indis_w;

reg                     bib_istek_gecerli_cmb;
reg [31:0]              bib_veri_cmb;

reg                     bellek_veri_r;
reg                     bellek_veri_ns;

reg                     yo_gecerli_cmb;

reg                     duraklat_cmb;

reg[1:0]                durum_r;
reg[1:0]                durum_ns;

localparam OKU   = 0;
localparam HAZIR = 1;

always @* begin
   ns             = bellek_i;
   yo_gecerli_cmb = 1'b0;

   bib_istek_gecerli_cmb = 1'b0;
   duraklat_cmb          = 1'b0;
   durum_ns              = durum_r;
   
   case(durum_r)
      HAZIR: begin
         if (yaz_w && gecerli_w) begin
            bib_istek_gecerli_cmb = 1'b1;
            duraklat_cmb          = !vyb_hazir_w;
         end
         if (oku_w && gecerli_w) begin
            bib_istek_gecerli_cmb = 1'b1;
            duraklat_cmb          = 1'b1;
            durum_ns              = vyb_hazir_w ? OKU : HAZIR;
         end
      end
      OKU: begin
         duraklat_cmb = 1'b1;
         if (bellek_gecerli_w) begin // bana veri gelmiþ demektir 
            yo_gecerli_cmb = 1'b1;
            case (buyruk_secim_w)
               `BIB_LW: begin // 32 Bit Okur
                  ns[45+:32] = bellek_veri_w;   
               end
               `BIB_LH: begin // 16 Bit Okur, sign-extend edip rd'ye yazar
                  ns[45+:32] = $signed(bellek_veri_w[bayt_indis_w * 8 +: 16]);
               end
               `BIB_LHU: begin // 16 Bit Okur, zero-extend edip rd'ye yazar
                  ns[45+:32] = {16'b0, bellek_veri_w[bayt_indis_w * 8 +: 16]};       
               end
               `BIB_LB: begin // 8 Bit Okur, sign-extend edip rd'ye yazar
                  ns[45+:32] = $signed(bellek_veri_w[bayt_indis_w * 8 +: 8]);         
               end
               `BIB_LBU: begin // 8 Bit Okur, zero-extend edip rd'ye yazar
                  ns[45+:32] = {24'b0, bellek_veri_w[bayt_indis_w * 8 +: 8]};      
               end
            endcase
            duraklat_cmb = 1'b0;
            durum_ns = HAZIR;
         end
      end
   endcase

   ns[0] = !duraklat_cmb && gecerli_w;
end

always @(posedge clk_i) begin
   if (!rst_i) begin
      r             <= {219{1'b0}};
      bellek_veri_r <= 1'b0;
      durum_r       <= HAZIR;
   end
   else begin
      r             <= ns;
      bellek_veri_r <= bellek_veri_ns;
      durum_r       <= durum_ns;  
   end
end

bellek_islem_birimi bib (
   .clk_i                            ( clk_i               ),
   .rst_i                            ( rst_i              ),  
   .buyruk_secim_i                   ( buyruk_secim_w  ),          
   .rd_i                             ( rd_w            ),  
   .rs2_i                            ( rs2_w           ),  
   .veri_o                           ( bib_veri_w          ),
   .maske_o                          ( maske_w             ),
   .oku_o                            ( oku_w               ),
   .yaz_o                            ( yaz_w               )    
);

veri_yolu_birimi vyb ( 
   .clk_i                            ( clk_i                ),
   .rst_i                            ( rst_i                ),
   .port_istek_adres_o               ( l1v_istek_adres_o    ),
   .port_istek_gecerli_o             ( l1v_istek_gecerli_o  ),
   .port_istek_onbellekleme_o        ( l1v_istek_onbellekleme_o ),
   .port_istek_yaz_o                 ( l1v_istek_yaz_o      ),
   .port_istek_veri_o                ( l1v_istek_veri_o     ),
   .port_istek_maske_o               ( l1v_istek_maske_o    ),
   .port_istek_hazir_i               ( l1v_istek_hazir_i    ),
   .port_veri_i                      ( l1v_veri_i           ),
   .port_veri_gecerli_i              ( l1v_veri_gecerli_i   ),
   .port_veri_hazir_o                ( l1v_veri_hazir_o     ),
   .bib_istek_gecerli_i              ( bib_istek_gecerli_w  ),
   .bib_istek_yaz_i                  ( bib_istek_yaz_w      ),
   .bib_veri_i                       ( bib_veri_w           ),  // yazýlacak veri
   .bib_istek_oku_i                  ( bib_istek_oku_w      ),
   .bib_istek_adres_i                ( bib_istek_adres_w    ),
   .bib_istek_maske_i                ( bib_istek_maske_w    ),
   .bellek_hazir_o                   ( vyb_hazir_w          ),
   .bellek_veri_o                    ( bellek_veri_w        ),
   .bellek_gecerli_o                 ( bellek_gecerli_w     )   // islem bitti sinyali
);

assign geri_yaz_o = r;

assign ps_w             = bellek_i[1+:32];
assign gecerli_w        = bellek_i[0];
assign tag_w            = bellek_i[33+:4];

assign rs1_w            = bellek_i[141+:32];
assign rs2_w            = bellek_i[109+:32];
assign rd_w             = bellek_i[45+:32];
assign imm_w            = bellek_i[77+:32];
assign taken_w          = bellek_i[173];
assign buyruk_secim_w   = bellek_i[173+:32];
assign bayt_indis_w     = rd_w[1:0];

assign bib_istek_maske_w    = maske_w;
assign bib_istek_yaz_w      = yaz_w;
assign bib_istek_oku_w      = oku_w;
assign bib_istek_adres_w    = rd_w;
assign bib_istek_gecerli_w  = bib_istek_gecerli_cmb;

assign yo_veri_o            = ns[45+:32];
assign yo_adres_o           = bellek_i[37+:5];
assign yo_gecerli_o         = yo_gecerli_cmb && gecerli_w;
assign yo_etiket_o          = tag_w;

assign duraklat_o           = duraklat_cmb;




endmodule
